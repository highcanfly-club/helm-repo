#!/bin/bash

# Copyright (c) 2024-2026 Ronan LE MEILLAT
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.


# sync-charts.sh - mirror Helm charts from their GitHub sources, package them
# (dependencies included) into repo/ and regenerate repo/index.yaml + index.html.
#
# Usage:
#   ./sync-charts.sh                          sync every chart of the CHARTS table
#   ./sync-charts.sh [-f] [-j N]              -f: ignore the cache, -j: parallel downloads (default 6)
#   ./sync-charts.sh REPO PATH [BRANCH]       sync one chart (legacy form REPO PATH STRIP [BRANCH] still accepted)
#
# How it works:
#   1. Each source ref (branch/HEAD) is resolved to a commit SHA with `git ls-remote`
#      (cheap, no API rate limit). A chart whose SHA is unchanged since the last run
#      (charts/.sync-state.tsv) and whose package is still in repo/ is skipped: no download,
#      no repackaging, so no churn in git (helm package output is not byte-reproducible).
#   2. Changed sources are downloaded in parallel as a tarball pinned to that SHA.
#   3. Packaging is serial (shared helm cache): missing chart dependencies are fetched in a
#      scratch copy (`helm dependency build`, falling back to `update`), so charts/ stays a
#      pristine mirror of the sources. Repositories declared by the charts are added on the fly.
#   4. A failing chart does not stop the others; its previous package stays published and the
#      script exits 1 at the end. index.yaml/index.html are only rebuilt when something changed.
#
# Environment: GITHUB_TOKEN (optional) is used for git/codeload requests (private repos, rate limits).

set -Eeuo pipefail

cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

REPO_URL="https://helm-repo.highcanfly.club"
STATE_FILE="charts/.sync-state.tsv"
JOBS=6
FORCE=0

# Source table: "github-repo|path-in-repo|ref". Empty ref = default branch (HEAD).
# The chart directory is located below <path> (nested layouts are detected), the mirror
# goes to charts/<basename of path>, the package name comes from Chart.yaml.
CHARTS=(
        "eltorio/minio-prometheus-chart|helm/minio|"
        "eltorio/cert-manager-webhook-cloudns|deploy/cert-manager-webhook-cloudns|"
        "eltorio/whois-rest|helm/whois-rest|"
        "highcanfly-club/cert-manager-webhook-oci|cert-manager-webhook-oci|"
        "highcanfly-club/crontab-ui|helm/crontab-ui|"
        "highcanfly-club/docker-smtp-relay|helm/flex-smtpd|"
        "highcanfly-club/easyappointments-k8s|helm/easyappointments|"
        "highcanfly-club/gitea-bitnami-custom|helm/gitea|"
        "highcanfly-club/hcf-coder|helm/hcf-coder|"
        "highcanfly-club/hcfmailer-plus|helm/hcfmailerplus|"
        "highcanfly-club/hcfmailer|helm/hcfmailer|"
        "highcanfly-club/hcfschedule|helm/hcfschedule|hcf"
        "highcanfly-club/helm-dashboard|helm/helm-dashboard|"
        "highcanfly-club/helm-roundecubemail|roundcube|"
        "highcanfly-club/odoo-bitnami-custom|helm/odoo|"
        "highcanfly-club/pretix|helm/pretix|"
        "highcanfly-club/ubuntu-net-tools-image|helm/cloudflared|"
        "highcanfly-club/ubuntu-w64build|helm/ubuntu-w64build|"
        "ismogroup/dolidock|helm/dolidock|"
        "sctg-development/sctgdesk|helm/sctgdesk|"
        "sctg-development/web-smtp-relay|helm/web-smtp-relay|"
        "sctg-development/nginx-ad-auth|helm/nginx-ad-auth|"
        "sctg-development/rallly|helm/rallly|"
        "sctg-development/tokeisrv|helm/tokeisrv|"
        "sctg-development/ollama-k8s|ollama-helm|"
        "sctg-development/sctg-claw|sctg-claw|"
        "sctg-development/openwrt-asu|helm/openwrt-asu|"
        "sctg-development/stepca-ui|chart/step-certificates|"
        # Fork carrying https://github.com/semaphoreui/charts/pull/32 (sqlite dialect accepted by values.schema.json).
        # Drop it for upstream "semaphoreui/charts|stable/semaphore|" once the PR is merged and released.
        "fabiofilz/semaphore-charts-fork|stable/semaphore|fix/sqlite-database-type"
)

log() { printf '%s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------- command line
ONLY=()
while [[ $# -gt 0 ]]; do
        case $1 in
        -f | --force) FORCE=1; shift ;;
        -j | --jobs) JOBS=${2:?-j needs a number}; shift 2 ;;
        -h | --help) sed -n '/^# sync-charts.sh/,/^set -E/p' "$0" | sed '$d; s/^# \{0,1\}//'; exit 0 ;;
        *) ONLY+=("$1"); shift ;;
        esac
done
[[ $JOBS =~ ^[0-9]+$ && $JOBS -ge 1 ]] || die "invalid job count: $JOBS"

SINGLE=0
if [[ ${#ONLY[@]} -ge 2 ]]; then
        # legacy: REPO PATH STRIP [BRANCH]   new: REPO PATH [BRANCH]; STRIP is obsolete (the chart is located automatically)
        if [[ ${ONLY[2]:-} =~ ^[0-9]+$ ]]; then ONLY=("${ONLY[0]}" "${ONLY[1]}" "${ONLY[3]:-}"); fi
        [[ ${ONLY[0]} == */* ]] || die "first argument must be 'owner/repo'"
        CHARTS=("${ONLY[0]}|${ONLY[1]}|${ONLY[2]:-}")
        SINGLE=1
elif [[ ${#ONLY[@]} -eq 1 ]]; then
        die "expected REPO PATH [BRANCH]"
fi

# ---------------------------------------------------------------- prerequisites / environment
for tool in curl tar git helm flock awk sed find sha1sum xargs; do
        command -v "$tool" >/dev/null || die "missing required tool: $tool"
done

# one run at a time (the script itself is the lock)
exec 9<"$0"
flock -n 9 || die "another sync-charts.sh is already running"

export GIT_TERMINAL_PROMPT=0 # a missing/private repo must fail, not wait for a password
if [[ -n ${GITHUB_TOKEN:-} ]]; then
        export GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0="http.https://github.com/.extraheader"
        GIT_CONFIG_VALUE_0="Authorization: Basic $(printf 'x-access-token:%s' "$GITHUB_TOKEN" | base64 -w0)"
        export GIT_CONFIG_VALUE_0
fi

WORK=$(mktemp -d "${TMPDIR:-/tmp}/sync-charts.XXXXXX")
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK"/{src,res,log,build,pkg} charts repo

# ---------------------------------------------------------------- phase 1 worker (runs in parallel)
# fetch_one ID REPO PATH REF -> $WORK/res/ID = "status<TAB>sha<TAB>chart dir" with status unchanged|fetched|error
fetch_one() {
        local id=$1 repo=$2 path=$3 ref=$4
        local key="$repo|$path|${ref/#HEAD/}" sha tgz_known known_sha n
        local TOKEN_ARGS=() # arrays cannot be exported: rebuilt here
        [[ -z ${GITHUB_TOKEN:-} ]] || TOKEN_ARGS=(-H "Authorization: Bearer ${GITHUB_TOKEN}")

        local out="$WORK/res/$id"
        fail() { printf 'error\t\t\n' >"$out"; echo "  FAILED: $*"; return 0; }

        # 1. resolve the ref to a commit SHA
        local pattern=${ref:-HEAD}
        [[ $ref == HEAD || -z $ref ]] || pattern="refs/heads/$ref"
        sha=""
        for n in 1 2 3; do
                sha=$(git ls-remote "https://github.com/${repo}.git" "$pattern" 2>/dev/null | awk 'NR==1{print $1}') && [[ -n $sha ]] && break
                sleep $((n * 2))
        done
        if [[ -z $sha && -n $ref && $ref != HEAD ]]; then # maybe a tag
                sha=$(git ls-remote "https://github.com/${repo}.git" "refs/tags/$ref" 2>/dev/null | awk 'NR==1{print $1}') || true
        fi
        [[ $sha =~ ^[0-9a-f]{40}$ ]] || { fail "cannot resolve ${ref:-HEAD} of ${repo} (missing repo, branch or network?)"; return 0; }

        # 2. unchanged since the last run and package still published -> nothing to do
        read -r known_sha tgz_known < <(awk -F'\t' -v k="$key" '$1==k{print $2, $3}' "$WORK/state.tsv" 2>/dev/null) || true
        if [[ $FORCE -eq 0 && ${known_sha:-} == "$sha" && -n ${tgz_known:-} && -f repo/$tgz_known ]]; then
                printf 'unchanged\t%s\t\n' "$sha" >"$out"
                echo "  up to date @ ${sha:0:9} ($tgz_known)"
                return 0
        fi

        # 3. download the tarball pinned to that SHA
        local archive="$WORK/src/$id.tar.gz" top="${repo#*/}-${sha}" dest="$WORK/src/$id"
        echo "  downloading ${repo}@${sha:0:9} (${ref:-HEAD})"
        curl -fsSL --retry 3 --retry-delay 2 --connect-timeout 15 --max-time 300 "${TOKEN_ARGS[@]}" \
                -o "$archive" "https://codeload.github.com/${repo}/tar.gz/${sha}" || { fail "download failed"; return 0; }
        mkdir -p "$dest"

        # 4. extract only the wanted subtree; fall back to the whole archive when the path is not exact
        if ! tar -xzf "$archive" -C "$dest" "$top/$path" 2>/dev/null; then
                tar -xzf "$archive" -C "$dest" || { fail "corrupt archive"; return 0; }
        fi
        rm -f "$archive"

        # 5. locate the chart directory (Chart.yaml), ignoring vendored sub-charts
        local base="$dest/$top/$path" chart="" cands=() c
        if [[ -f $base/Chart.yaml ]]; then
                chart=$base
        else
                mapfile -t cands < <(find "$dest/$top" -name Chart.yaml -not -path '*/charts/*' -printf '%h\n' 2>/dev/null | sort)
                # prefer the directory named like the path, else accept a single unambiguous candidate
                for c in "${cands[@]}"; do
                        [[ ${c##*/} == "$(basename "$path")" ]] && { chart=$c; break; }
                done
                [[ -n $chart || ${#cands[@]} -ne 1 ]] || chart=${cands[0]}
        fi
        [[ -n $chart && -f $chart/Chart.yaml ]] || { fail "no Chart.yaml found under '$path'"; return 0; }
        [[ $chart == "$base" ]] || echo "  chart located in ${chart#"$dest/$top/"} (path '$path' is not the chart directory itself)"

        printf 'fetched\t%s\t%s\n' "$sha" "$chart" >"$out"
}

# fetch_line "ID<TAB>REPO<TAB>PATH<TAB>REF" : wraps fetch_one with a per-chart log file
fetch_line() {
        local id repo path ref
        IFS=$'\t' read -r id repo path ref <<<"$1"
        { echo "[$repo $path]"; fetch_one "$id" "$repo" "$path" "$ref"; } >"$WORK/log/$id" 2>&1 || true
        [[ -f $WORK/res/$id ]] || printf 'error\t\t\n' >"$WORK/res/$id"
}
export -f fetch_one fetch_line
export WORK FORCE
export GITHUB_TOKEN="${GITHUB_TOKEN:-}"

# ---------------------------------------------------------------- helpers for phase 2
# ensure_deps DIR : fetch missing chart dependencies in DIR (a scratch copy)
ensure_deps() {
        local dir=$1 url name
        grep -qE '^[[:space:]]*(-[[:space:]]+)?repository:' "$dir/Chart.yaml" || return 0
        # missing / wrong / corrupt dependency? (vendored ones are left alone)
        local status
        status=$(helm dependency list "$dir" 2>/dev/null) || true # captured first: no SIGPIPE race with grep -q
        grep -qE '[[:space:]](missing|wrong version|corrupt|too many matches)[[:space:]]*$' <<<"$status" || return 0
        # classic repositories must be known to helm; oci:// and file:// need nothing
        while read -r url; do
                [[ $url =~ ^https?:// ]] || continue
                name="sync-$(printf '%s' "$url" | sha1sum | cut -c1-10)"
                helm repo add --force-update "$name" "$url" >/dev/null
        done < <(sed -nE "s/^[[:space:]]*(-[[:space:]]+)?repository:[[:space:]]*['\"]?([^'\"[:space:]]+).*/\2/p" "$dir/Chart.yaml" | sort -u)
        echo "  fetching dependencies"
        # `build` honours Chart.lock (reproducible); it fails when the lock is stale or constraints are ranges
        helm dependency build "$dir" >/dev/null 2>&1 || helm dependency update "$dir" >/dev/null
}

# ---------------------------------------------------------------- phase 1: resolve + download (parallel)
[[ -f $STATE_FILE ]] && cp "$STATE_FILE" "$WORK/state.tsv" || : >"$WORK/state.tsv"

IDS=() KEYS=() NAMES=()
declare -A SEEN=()
: >"$WORK/list"
for i in "${!CHARTS[@]}"; do
        IFS='|' read -r repo path ref <<<"${CHARTS[$i]}"
        [[ -n $repo && -n $path ]] || die "bad CHARTS entry: ${CHARTS[$i]}"
        name=$(basename "$path")
        [[ -z ${SEEN[$name]:-} ]] || die "two sources would be mirrored to charts/$name"
        SEEN[$name]=1
        IDS+=("$i"); KEYS+=("$repo|$path|$ref"); NAMES+=("$name")
        printf '%s\t%s\t%s\t%s\n' "$i" "$repo" "$path" "${ref:-HEAD}" >>"$WORK/list"
done
# the key stores the ref exactly as written in the table (empty stays empty)
log "Checking ${#CHARTS[@]} source(s), ${JOBS} in parallel..."
xargs -a "$WORK/list" -d '\n' -P "$JOBS" -I{} bash -c 'fetch_line "$1"' _ {} || true
for i in "${IDS[@]}"; do cat "$WORK/log/$i"; done

# ---------------------------------------------------------------- phase 2: package (serial)
FAILED=() UPDATED=() UNCHANGED=0
: >"$WORK/state.new"
for i in "${IDS[@]}"; do
        IFS=$'\t' read -r status sha chart <"$WORK/res/$i"
        key=${KEYS[$i]}; name=${NAMES[$i]}
        key_state=${key/%|HEAD/|} # normalise: HEAD == empty ref
        case $status in
        unchanged)
                UNCHANGED=$((UNCHANGED + 1))
                awk -F'\t' -v k="$key_state" '$1==k' "$WORK/state.tsv" >>"$WORK/state.new"
                continue ;;
        error | "")
                FAILED+=("$name (download)")
                awk -F'\t' -v k="$key_state" '$1==k' "$WORK/state.tsv" >>"$WORK/state.new" # keep the old state
                continue ;;
        esac

        log "[$name] packaging"
        build="$WORK/build/$i"
        pkg="$WORK/pkg/$i"
        if ! { cp -a "$chart" "$build" && ensure_deps "$build" && helm package "$build" -d "$pkg" >/dev/null; } 2>"$WORK/log/$i.pkg"; then
                sed 's/^/  /' "$WORK/log/$i.pkg" >&2
                FAILED+=("$name (package)")
                awk -F'\t' -v k="$key_state" '$1==k' "$WORK/state.tsv" >>"$WORK/state.new"
                continue
        fi
        tgz=$(find "$pkg" -maxdepth 1 -name '*.tgz' -printf '%f\n' | head -n1)
        [[ -n $tgz ]] || { FAILED+=("$name (no package produced)"); continue; }

        mv -f "$pkg/$tgz" "repo/$tgz"
        rm -rf "charts/$name" && cp -a "$chart" "charts/$name" # pristine source mirror
        printf '%s\t%s\t%s\n' "$key_state" "$sha" "$tgz" >>"$WORK/state.new"
        UPDATED+=("$tgz")
        log "  -> repo/$tgz"
done

# single mode: keep the cache of every other chart
if [[ $SINGLE -eq 1 ]]; then
        awk -F'\t' -v k="${KEYS[0]/%|HEAD/|}" '$1!=k' "$WORK/state.tsv" >>"$WORK/state.new"
fi
sort -u "$WORK/state.new" >"$STATE_FILE"

# ---------------------------------------------------------------- phase 3: index + html page
if [[ ${#UPDATED[@]} -gt 0 || $FORCE -eq 1 || ! -f repo/index.yaml ]]; then
        log "Rebuilding repo/index.yaml"
        helm repo index repo/ --url="$REPO_URL"

        # `helm repo-html --help` succeeds even with a broken binary (helm answers it itself), so test a real
        # render; on failure (plugin missing, binary from another architecture...) reinstall once and retry.
        render_html() { helm repo-html -i repo/index.yaml -o "$WORK/index.html" -t index.tpl >/dev/null 2>&1; }
        if ! render_html; then
                log "Installing helm-repo-html plugin"
                helm plugin uninstall repo-html >/dev/null 2>&1 || true
                # --verify only exists on recent helm; older ones do not verify anyway
                helm plugin install --verify=false https://github.com/halkeye/helm-repo-html >/dev/null 2>&1 ||
                        helm plugin install https://github.com/halkeye/helm-repo-html >/dev/null 2>&1 || true
        fi
        if render_html && [[ -s $WORK/index.html ]]; then
                cp "$WORK/index.html" repo/index.html
        else
                FAILED+=("index.html (helm-repo-html unusable)")
        fi
else
        log "Nothing changed: index left untouched."
fi

# ---------------------------------------------------------------- summary
log ""
log "Summary: ${#UPDATED[@]} updated, ${UNCHANGED} unchanged, ${#FAILED[@]} failed"
for t in "${UPDATED[@]}"; do log "  updated: $t"; done
if [[ ${#FAILED[@]} -gt 0 ]]; then
        for f in "${FAILED[@]}"; do log "  FAILED: $f"; done
        exit 1
fi
