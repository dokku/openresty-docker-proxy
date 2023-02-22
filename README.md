# nginx-docker-proxy

## Usage

### Environment Variables

#### `NGINX_APP_LABEL`

> default: `com.dokku.app-name`

An docker label to group server blocks by.

#### `NGINX_LABEL_PREFIX`

> default: `nginx.`

The default prefix to use when looking up labels. All examples below assume the default label prefix.

#### `NGINX_PROCESS_LABEL`

> default: `com.dokku.process-type`

A secondary docker label to group process types within servers by.

#### `NGINX_WEB_PROCESS`

> default: `web`

The value of the `NGINX_PROCESS_LABEL` that denotes the primary `web` process to proxy.

#### `NGINX_DEFAULT_NETWORK`

> default: `bridge`

The default network to proxy requests to.

#### `NGINX_OS_PAGESIZE`

> default: computed on container start

The default os page size to base default proxy values on.

### Labels

#### `nginx.access-log-format`

#### `nginx.access-log-path`

#### `nginx.bind-address-ipv4`

#### `nginx.bind-address-ipv6`

#### `nginx.client-max-body-size`

#### `nginx.domains`

A space-delimited set of domains to proxy.

#### `nginx.error-log-path`

#### `nginx.https-port`

#### `nginx.include-http-*`

#### `nginx.include-tcp-*`

#### `nginx.include-udp-*`

#### `nginx.initial-network`

#### `nginx.letsencrypt`

#### `nginx.port-mapping`

Holds a space-delimited set of port mappings, where the port mapping is of the format `$scheme:$host_port:$container_port`. Supported schemes:

- tcp/udp: For stream proxying. Only labels that are explicitely called out are supported.
- http/https: For normal request proxying. Supports most labels unless otherwise specified.

#### `nginx.proxy-buffer-size`

#### `nginx.proxy-buffering`

#### `nginx.proxy-buffers`

#### `nginx.proxy-busy-buffer-size`

#### `nginx.proxy-read-timeout`

#### `nginx.x-forwarded-for-value`

#### `nginx.x-forwarded-port-value`

#### `nginx.x-forwarded-proto-value`

#### `nginx.x-forwarded-ssl`

## TODO

- Add documentation for all labels
- Add lego integration
- Add logrotation for internal app logs
- Add automatic releases
- Skip apps without domain
- Skip apps without proxy port mapping
