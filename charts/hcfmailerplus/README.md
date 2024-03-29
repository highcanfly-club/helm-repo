# Install with helm
```sh
helm repo add highcanfly https://helm-repo.highcanfly.club/ 
helm repo update highcanfly
helm install --create-namespace --namespace hcfmailer-plus hcfmailerplus highcanfly/hcfmailerplus --set cloudflare.zoneId=412b0ec63257e7ef9512eebda418216c \
                    --set cloudflare.apiKey=keoYaR5aing6eeThooquai-zeng5Oupu9Yi \
                    --set cloudflare.dnsRecord=smtp-hcfp.example.org \
                    --set app.HOST_BASE_TRUSTED=hcfmailer-plus.example.org \
                    --set app.URL_BASE_TRUSTED=https://hcfmailer-plus.example.org \
                    --set app.HOST_BASE_SANDBOX=hcfmailer-plus-sandbox.example.org \
                    --set app.URL_BASE_SANDBOX=https://hcfmailer-plus-sandbox.example.org \
                    --set app.HOST_BASE_PUBLIC=hcfmailer-plus-public.example.org \
                    --set app.URL_BASE_PUBLIC=https://hcfmailer-plus-public.example.org \
                    --set app.HOST_BASE_PHPMYADMIN=hcfmailer-plus-phpmyadmin.example.org \
                    --set ingress.clusterIssuer=company-ca-issuer \
                    --set ingress.annotations."traefik\.ingress\.kubernetes\.io/router\.entrypoints"=websecure \
                    --set ingress.annotations."external\-dns\.alpha\.kubernetes\.io/target"="ha.example.org" 
```

for compatibility with /k8s/k8s.yml you can use:
```sh
helm repo add highcanfly https://helm-repo.highcanfly.club/ 
helm repo update highcanfly
helm install --create-namespace --namespace hcfmailer-plus hcfmailerplus highcanfly/hcfmailerplus --set cloudflare.zoneId=$CLOUDFLARE_ZONE_ID \
                    --set cloudflare.apiKey=$CLOUDFLARE_API_KEY \
                    --set cloudflare.dnsRecord=$CLOUDFLARE_DNS_RECORDS \
                    --set app.HOST_BASE_TRUSTED=$HOST_BASE_TRUSTED \
                    --set app.URL_BASE_TRUSTED=$URL_BASE_TRUSTED \
                    --set app.HOST_BASE_SANDBOX=$HOST_BASE_SANDBOX \
                    --set app.URL_BASE_SANDBOX=$URL_BASE_SANDBOX \
                    --set app.HOST_BASE_PUBLIC=$HOST_BASE_PUBLIC \
                    --set app.URL_BASE_PUBLIC=$URL_BASE_PUBLIC \
                    --set app.HOST_BASE_PHPMYADMIN=hcfmailer-plus-phpmyadmin.example.org \
                    --set ingress.clusterIssuer=company-ca-issuer \
                    --set ingress.annotations."traefik\.ingress\.kubernetes\.io/router\.entrypoints"=websecure \
                    --set ingress.annotations."external\-dns\.alpha\.kubernetes\.io/target"="ha.example.org" 
```