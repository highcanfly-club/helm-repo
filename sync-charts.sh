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
mv crontab-ui-*.tgz hcfmailer-*.tgz dolidock-*.tgz repo/
helm repo index repo/ --url=https://helm-repo.highcanfly.club