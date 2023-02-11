# nginx-docker-proxy

## Usage

### Environment Variables

#### `NGINX_APP_LABEL`

#### `NGINX_PROCESS_LABEL`

#### `NGINX_WEB_PROCESS`

#### `NGINX_DEFAULT_NETWORK`

#### `NGINX_OS_PAGESIZE`

### Labels

#### `nginx.access-log-format`

#### `nginx.access-log-path`

#### `nginx.bind-address-ipv4`

#### `nginx.bind-address-ipv6`

#### `nginx.client-max-body-size`

#### `nginx.domains`

#### `nginx.error-log-path`

#### `nginx.https-port`

#### `nginx.include-*`

#### `nginx.initial-network`

#### `nginx.port-mapping`

#### `nginx.proxy-buffer-size`

#### `nginx.proxy-buffering`

#### `nginx.proxy-buffers`

#### `nginx.proxy-busy-buffer-size`

#### `nginx.proxy-read-timeout`

#### `nginx.x-forwarded-for-value`

#### `nginx.x-forwarded-port-value`

#### `nginx.x-forwarded-proto-value`

#### `nginx.x-forwarded-proto-value`

## TODO

- Add documentation for all labels
- Add lego integration
- Add logrotation for internal app logs
- Add automatic releases
- Skip apps without domain
- Skip apps without proxy port mapping
