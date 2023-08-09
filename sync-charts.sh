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
curl -J -L https://github.com/highcanfly-club/ubuntu-w64build/archive/HEAD.tar.gz  | tar xvz -C charts --strip 2 $TAR_WILDCARDS "*helm/ubuntu-w64build*"
helm package charts/ubuntu-w64build
curl -J -L https://github.com/highcanfly-club/helm-dashboard/archive/HEAD.tar.gz  | tar xvz -C charts --strip 2 $TAR_WILDCARDS "*helm/helm-dashboard*"
helm package charts/helm-dashboard
curl -J -L https://github.com/highcanfly-club/hcfmailer-plus/archive/HEAD.tar.gz | tar xvz -C charts --strip 3 $TAR_WILDCARDS "*helm/hcfmailerplus*"
helm package charts/hcfmailerplus
curl -J -L https://github.com/highcanfly-club/easyappointments-k8s/archive/HEAD.tar.gz | tar xvz -C charts --strip 2 $TAR_WILDCARDS "*helm/easyappointments*"
helm package charts/easyappointments
curl -J -L https://github.com/highcanfly-club/hcfschedule/archive/hcf.tar.gz | tar xvz -C charts --strip 2 $TAR_WILDCARDS "*helm/hcfschedule*"
helm package charts/hcfschedule
curl -J -L https://github.com/highcanfly-club/pretix/archive/hcf.tar.gz | tar xvz -C charts --strip 2 $TAR_WILDCARDS "*helm/pretix*"
helm package charts/pretix
curl -J -L https://github.com/highcanfly-club/helm-roundecubemail/archive/HEAD.tar.gz | tar xvz -C charts --strip 1 $TAR_WILDCARDS "*roundcube*"
helm package charts/roundcube
mv crontab-ui-*.tgz hcfmailer-*.tgz dolidock-*.tgz cert-manager-*.tgz ubuntu-w64build-*.tgz helm-dashboard-*.tgz helm hcfmailerplus-*.tgz easyappointments-*.tgz hcfschedule-*.tgz pretix-*.tgz roundcube-*.tgz repo/
helm repo index repo/ --url=https://helm-repo.highcanfly.club