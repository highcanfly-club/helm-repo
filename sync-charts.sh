#!/bin/bash
if [[ "$OSTYPE" == "darwin"* ]]; then
        TAR_WILDCARDS=""
else
        TAR_WILDCARDS="--wildcards"
fi

get_repo() {
    repo=$1
    path=$2
    strip=$3
    _name=$(basename $path)
    echo $_name
    curl -J -L  https://github.com/${repo}/archive/HEAD.tar.gz | tar xvz -C charts --strip ${strip} $TAR_WILDCARDS "*${path}*"
    helm package charts/${_name}
    mv ${_name}-*.tgz repo/
}

if [[ -n $1 && -n $2 && -n $3 ]]; then
        get_repo $1 $2 $3
else
        get_repo "eltorio/minio-prometheus-chart" "helm/minio" 2
        get_repo "eltorio/whois-rest" "helm/whois-rest" 2
        get_repo "highcanfly-club/cert-manager-webhook-oci" "cert-manager-webhook-oci" 2
        get_repo "highcanfly-club/crontab-ui" "helm/crontab-ui" 3
        get_repo "highcanfly-club/docker-smtp-relay" "helm/flex-smtpd" 2
        get_repo "highcanfly-club/easyappointments-k8s" "helm/easyappointments" 2
        get_repo "highcanfly-club/gitea-bitnami-custom" "helm/gitea" 2
        get_repo "highcanfly-club/hcf-coder" "helm/hcf-coder" 2
        get_repo "highcanfly-club/hcfmailer-plus" "helm/hcfmailerplus" 3
        get_repo "highcanfly-club/hcfmailer" "helm/hcfmailer" 3
        get_repo "highcanfly-club/hcfschedule" "helm/hcfschedule" 2
        get_repo "highcanfly-club/helm-dashboard" "helm/helm-dashboard" 2
        get_repo "highcanfly-club/helm-roundecubemail" "roundcube" 1
        get_repo "highcanfly-club/odoo-bitnami-custom" "helm/odoo" 2
        get_repo "highcanfly-club/pretix" "helm/pretix" 2
        get_repo "highcanfly-club/ubuntu-w64build" "helm/ubuntu-w64build" 2
        get_repo "ismogroup/dolidock" "helm/dolidock" 2
fi
helm repo index repo/ --url=https://helm-repo.highcanfly.club
# needs to install repo-html plugin;
# helm plugin install https://github.com/halkeye/helm-repo-html
helm repo-html -i repo/index.yaml -o repo/index.html -t index.tpl
