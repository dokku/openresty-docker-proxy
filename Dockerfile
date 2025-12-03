FROM golang:1.25.5 as forego

ARG FOREGO_VERSION=v0.17.2

WORKDIR /go/forego

RUN git clone https://github.com/nginx-proxy/forego . \
    && git -c advice.detachedHead=false checkout $FOREGO_VERSION \
    && go mod download \
    && CGO_ENABLED=0 GOOS=linux go build -o forego . \
    && go clean -cache \
    && mv forego /usr/local/bin/forego

FROM ubuntu:24.04 as downloads

RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends ca-certificates=* curl=* && \
    rm -rf /var/lib/apt/lists/*

ARG DOCKER_GEN_VERSION=0.13.0
RUN curl -o /tmp/docker-gen.tar.gz -L "https://github.com/nginx-proxy/docker-gen/releases/download/${DOCKER_GEN_VERSION}/docker-gen-linux-$(dpkg --print-architecture)-${DOCKER_GEN_VERSION}.tar.gz" && \
    tar xvzf /tmp/docker-gen.tar.gz -C /usr/local/bin

ARG DEHYDRATED_VERSION=0.7.1
RUN curl -o /tmp/docker-gen.tar.gz -L "https://github.com/dehydrated-io/dehydrated/releases/download/v${DEHYDRATED_VERSION}/dehydrated-${DEHYDRATED_VERSION}.tar.gz" && \
    tar xvzf /tmp/docker-gen.tar.gz && \
    mv dehydrated-${DEHYDRATED_VERSION}/dehydrated /usr/local/bin/dehydrated && \
    chmod +x /usr/local/bin/dehydrated

FROM ubuntu:24.04

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends bsdmainutils=* ca-certificates=* luarocks=* gcc=* gnupg=* logrotate=* make=* wget=* && \
    wget -nv -O - https://openresty.org/package/pubkey.gpg | gpg --dearmor -o /usr/share/keyrings/openresty.gpg && \
    (if [ "$(dpkg --print-architecture)" = "amd64" ]; then echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/openresty.gpg] http://openresty.org/package/ubuntu jammy main" > /etc/apt/sources.list.d/openresty.list; fi) && \
    (if [ "$(dpkg --print-architecture)" = "arm64" ]; then echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/openresty.gpg] http://openresty.org/package/arm64/ubuntu jammy main" > /etc/apt/sources.list.d/openresty.list; fi) && \
    cat /etc/apt/sources.list.d/openresty.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends openresty=* openresty-opm=* && \
    luarocks install lua-resty-auto-ssl && \
    ln -sf /usr/local/openresty/nginx/conf /etc/nginx && \
    mkdir -p /etc/resty-auto-ssl/letsencrypt/conf.d /etc/nginx/ssl /etc/nginx/stream-sites-enabled /etc/nginx/sites-enabled /var/log/nginx && \
    chown www-data /etc/resty-auto-ssl/ && \
    chown root:adm /var/log/nginx && \
    apt-get purge -y gcc make && \
    rm -f /etc/nginx/sites-enabled/default && \
    apt-get -y --purge autoremove && \
    apt-get -y clean autoclean && \
    rm -rf \
    /tmp/* \
    /var/cache/apk/* \
    /var/tmp/* \
    /var/lib/apt/lists/* \
    /var/log/alternatives.log \
    /var/log/apt/ \
    /var/log/bootstrap.log \
    /var/log/btmp \
    /var/log/dpkg.log \
    /var/log/faillog \
    /var/log/fsck/ \
    /var/log/lastlog \
    /var/log/wtmp \
    /root/.cache \
    && \
    mkdir -p /etc/nginx/lua && \
    find /var/cache/ ! -type d -exec rm '{}' \;

COPY config/allow_domain.lua /etc/nginx/lua/allow_domain.lua
COPY config/logrotate /etc/logrotate.d/openresty
COPY config/init.d /etc/init.d/openresty
COPY config/nginx.conf /etc/nginx/nginx.conf
COPY --from=forego /usr/local/bin/forego /usr/local/bin/forego
COPY --from=downloads /usr/local/bin/docker-gen /usr/local/bin/docker-gen
COPY --from=downloads /usr/local/bin/dehydrated /usr/local/bin/resty-auto-ssl/dehydrated
COPY ["bin", "/usr/local/bin/"]
COPY ["config.toml", "Procfile", "/app/"]
COPY ["templates", "/app/templates/"]

WORKDIR /app
CMD ["forego", "start", "-r"]
ENTRYPOINT ["/usr/local/bin/entrypoint"]

ENV DOCKER_HOST unix:///var/run/docker.sock
