FROM golang:1.20.6 as forego

ARG FOREGO_VERSION=v0.17.0

WORKDIR /go/forego

RUN git clone https://github.com/nginx-proxy/forego . \
    && git -c advice.detachedHead=false checkout $FOREGO_VERSION \
    && go mod download \
    && CGO_ENABLED=0 GOOS=linux go build -o forego . \
    && go clean -cache \
    && mv forego /usr/local/bin/forego

FROM ubuntu:22.04 as downloads

RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends ca-certificates=* curl=* && \
    rm -rf /var/lib/apt/lists/*

ARG DOCKER_GEN_VERSION=0.10.0
RUN curl -o /tmp/docker-gen.tar.gz -L "https://github.com/nginx-proxy/docker-gen/releases/download/${DOCKER_GEN_VERSION}/docker-gen-linux-$(dpkg --print-architecture)-${DOCKER_GEN_VERSION}.tar.gz" && \
    tar xvzf /tmp/docker-gen.tar.gz -C /usr/local/bin

ARG LEGO_VERSION=4.10.0
RUN dpkg --print-architecture > /tmp/architecture && \
    (test "$(cat /tmp/architecture)" = "armhf" && echo "armv7" > /tmp/architecture) && \
    curl -o /tmp/lego.tar.gz -L "https://github.com/go-acme/lego/releases/download/v${LEGO_VERSION}/lego_v${LEGO_VERSION}_linux_$(cat /tmp/architecture).tar.gz" && \
    tar xvzf /tmp/lego.tar.gz -C /usr/local/bin

FROM ubuntu:22.04

RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends nginx=* python3=* && \
    rm -rf /var/lib/apt/lists/*

COPY --from=forego /usr/local/bin/forego /usr/local/bin/forego
COPY --from=downloads /usr/local/bin/docker-gen /usr/local/bin/docker-gen

WORKDIR /app

COPY . /app

CMD ["forego", "start", "-r"]
ENTRYPOINT ["/app/entrypoint"]

ENV DOCKER_HOST unix:///var/run/docker.sock
