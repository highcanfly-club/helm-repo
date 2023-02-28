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
mv crontab-ui-0.3.16-rc.2.tgz hcfmailer-2.3.9-rc.9.tgz repo/