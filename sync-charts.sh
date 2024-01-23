#!/bin/bash
if [[ "$OSTYPE" == "darwin"* ]]; then
        TAR_WILDCARDS=""
else
        TAR_WILDCARDS="--wildcards"
fi

get_repo() {
    repo=$1
    name=$2
    strip=$3
    curl -J -L  https://github.com/${repo}/archive/HEAD.tar.gz | tar xvz -C charts --strip ${strip} $TAR_WILDCARDS "*${name}*"
    helm package charts/${name}
    mv ${name}-*.tgz repo/
}

if [[ -n $1 && -n $2 && -n $3 ]]; then
        get_repo $1 $2 $3
else
        get_repo "highcanfly-club/crontab-ui" "crontab-ui" 3
        get_repo "ismogroup/dolidock" "dolidock" 2
        get_repo "highcanfly-club/cert-manager-webhook-oci" "cert-manager-webhook-oci" 2
        get_repo "highcanfly-club/ubuntu-w64build" "ubuntu-w64build" 2
        get_repo "highcanfly-club/helm-dashboard" "helm-dashboard" 2
        get_repo "highcanfly-club/hcfmailer-plus" "hcfmailerplus" 3
        get_repo "highcanfly-club/easyappointments-k8s" "easyappointments" 2
        get_repo "highcanfly-club/hcfschedule" "hcfschedule" 2
        get_repo "highcanfly-club/pretix" "pretix" 2
        get_repo "highcanfly-club/helm-roundecubemail" "roundcube" 1
        get_repo "highcanfly-club/hcf-coder" "hcf-coder" 2
        get_repo "highcanfly-club/odoo-bitnami-custom" "odoo" 2
        get_repo "highcanfly-club/gitea-bitnami-custom" "gitea" 2
        get_repo "eltorio/minio-prometheus-chart" "minio" 2
        get_repo "eltorio/whois-rest" "whois-rest" 2
        get_repo "highcanfly-club/docker-smtp-relay" "flex-smtpd" 2
fi
helm repo index repo/ --url=https://helm-repo.highcanfly.club
# needs to install repo-html plugin;
# helm plugin install https://github.com/halkeye/helm-repo-html
helm repo-html -i repo/index.yaml -o repo/index.html -t index.tpl
