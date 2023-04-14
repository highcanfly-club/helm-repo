#!/bin/bash
if [[ "$OSTYPE" == "darwin"* ]]; then
        TAR_WILDCARDS=""
else
        TAR_WILDCARDS="--wildcards"
fi
curl -J -L  https://github.com/highcanfly-club/crontab-ui/archive/HEAD.tar.gz | tar xvz -C charts --strip 2 $TAR_WILDCARDS "*helm/crontab-ui*" 
helm package charts/crontab-ui
curl -J -L  https://github.com/highcanfly-club/hcfmailer/archive/HEAD.tar.gz | tar xvz -C charts --strip 3 $TAR_WILDCARDS "*helm/hcfmailer*"
helm package charts/hcfmailer
curl -J -L https://github.com/ismogroup/dolidock/archive/HEAD.tar.gz | tar xvz -C charts --strip 2 $TAR_WILDCARDS "*helm/dolidock*"
helm package charts/dolidock
curl -J -L https://github.com/highcanfly-club/cert-manager-webhook-oci/archive/HEAD.tar.gz  | tar xvz -C charts --strip 2 $TAR_WILDCARDS "*deploy*"
helm package charts/cert-manager-webhook-oci
mv crontab-ui-*.tgz hcfmailer-*.tgz dolidock-*.tgz cert-manager-*.tgz repo/
helm repo index repo/ --url=https://helm-repo.highcanfly.club