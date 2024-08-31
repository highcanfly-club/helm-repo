#!/bin/bash

# Copyright (c) 2024 Ronan LE MEILLAT
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

if [[ "$OSTYPE" == "darwin"* ]]; then
        TAR_WILDCARDS=""
else
        TAR_WILDCARDS="--wildcards"
fi

# get_repo is a function to download a specific path from a GitHub repository, package it with Helm, and move the package to the 'repo' directory.
# It takes four parameters:
#   - repo: The GitHub repository from which to download. It should be in the format 'username/repo'.
#   - path: The path within the repository to download.
#   - strip: The number of leading components from file names to strip. This is passed to the '--strip' option of 'tar'.
#   - branch: The branch of the repository to download. If not provided, it defaults to 'HEAD'.
#
# The function first checks if the 'branch' parameter is provided. If not, it sets 'branch' to 'HEAD'.
# It then downloads the specified path from the repository and extracts it into the 'charts' directory.
# After that, it packages the downloaded files with Helm and moves the package to the 'repo' directory.
get_repo() {
        repo=$1
        path=$2
        strip=$3
        branch=$4
        if [[ ! -n $branch ]]; then
                branch="HEAD"
        fi
        _name=$(basename $path)
        echo $_name
        echo "Downloading https://github.com/${repo}/archive/${branch}.tar.gz"
        curl -J -L https://github.com/${repo}/archive/${branch}.tar.gz | tar xvz -C charts --strip ${strip} $TAR_WILDCARDS "*${path}*"
        helm package charts/${_name}
        mv ${_name}-*.tgz repo/
}

if [[ -n $1 && -n $2 && -n $3 ]]; then
        repo=$1
        path=$2
        strip=$3
        branch=$4
        if [[ ! -n $branch ]]; then
                branch="HEAD"
        fi
        _name=$(basename $path)
        rm -rf charts/${_name}
        get_repo $1 $2 $3 $branch
else
        # clean up before sync
        find charts -mindepth 1 -type d -exec rm -rf {} +
        get_repo "eltorio/minio-prometheus-chart" "helm/minio" 2
        et_repo "eltorio/cert-manager-webhook-cloudns" "deploy/cert-manager-webhook-cloudns" 2
        get_repo "eltorio/whois-rest" "helm/whois-rest" 2
        get_repo "highcanfly-club/cert-manager-webhook-oci" "cert-manager-webhook-oci" 2
        get_repo "highcanfly-club/crontab-ui" "helm/crontab-ui" 2
        get_repo "highcanfly-club/docker-smtp-relay" "helm/flex-smtpd" 2
        get_repo "highcanfly-club/easyappointments-k8s" "helm/easyappointments" 2
        get_repo "highcanfly-club/gitea-bitnami-custom" "helm/gitea" 2
        get_repo "highcanfly-club/hcf-coder" "helm/hcf-coder" 2
        get_repo "highcanfly-club/hcfmailer-plus" "helm/hcfmailerplus" 3
        get_repo "highcanfly-club/hcfmailer" "helm/hcfmailer" 3
        get_repo "highcanfly-club/hcfschedule" "helm/hcfschedule" 2 hcf
        get_repo "highcanfly-club/helm-dashboard" "helm/helm-dashboard" 2
        get_repo "highcanfly-club/helm-roundecubemail" "roundcube" 1
        get_repo "highcanfly-club/odoo-bitnami-custom" "helm/odoo" 2
        get_repo "highcanfly-club/pretix" "helm/pretix" 2
        get_repo "highcanfly-club/ubuntu-net-tools-image" "helm/cloudflared" 2
        get_repo "highcanfly-club/ubuntu-w64build" "helm/ubuntu-w64build" 2
        get_repo "ismogroup/dolidock" "helm/dolidock" 2
        get_repo "sctg-development/sctgdesk" "helm/sctgdesk" 2
        get_repo "sctg-development/web-smtp-relay" "helm/web-smtp-relay" 2
        get_repo "sctg-development/nginx-ad-auth" "helm/nginx-ad-auth" 2
fi

# clean up
rm -rf charts/workflows charts/oci

helm repo index repo/ --url=https://helm-repo.highcanfly.club

if ! helm plugin list | grep -q repo-html; then
        echo "Installing helm-repo-html plugin"
        helm plugin install https://github.com/halkeye/helm-repo-html
fi

helm repo-html -i repo/index.yaml -o repo/index.html -t index.tpl
