# nginx-docker-proxy

Uses Openresty - an nginx-compatible server distribution - to proxy requests to other Docker containers based on configured labels.

## Usage

### Environment Variables

#### `NGINX_APP_LABEL`

> default: `com.dokku.app-name`

An docker label to group server blocks by.

#### `NGINX_DEBUG`

> default: `` (none)

Set to `true` to enable debugging comments in the generated config files.

#### `NGINX_LABEL_PREFIX`

> default: `nginx.`

The default prefix to use when looking up labels. All examples below assume the default label prefix.

#### `NGINX_LETSENCRYPT_EMAIL`

> default: `` (none)

The email to use for enabling letsencrypt (required).

#### `NGINX_LETSENCRYPT_CA`

> default: `https://acme-v02.api.letsencrypt.org/directory`

The certificate authority to use

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

The format of the nginx access log for the app.

#### `nginx.access-log-path`

The path - in the container - where the access logs will be written.

#### `nginx.bind-address-ipv4`

The IPv4 address - in the container - nginx will bind to when proxying requests.

#### `nginx.bind-address-ipv6`

The IPv6 address - in the container - nginx will bind to when proxying requests.

#### `nginx.client-max-body-size`

The value of `client_max_body_size`, used for limiting file upload size.

#### `nginx.domains`

A space-delimited set of domains to proxy.

#### `nginx.error-log-path`

The path - in the container - where the error logs will be written.

#### `nginx.https-port`

Port treated as https when parsing port mappings.

#### `nginx.include-grpc-*`

#### `nginx.include-http-*`

#### `nginx.include-tcp-*`

#### `nginx.include-udp-*`

#### `nginx.initial-network`

The network name to use when proxying requests to the app container.

#### `nginx.letsencrypt`

When set to `true`, this enables dynamic SSL certificate provisioning via Let's Encrypt for any `https:443` port mappings. Note that the corresponding `http:80` port mapping must exist in order for this to succeed.

#### `nginx.port-mapping`

Holds a space-delimited set of port mappings, where the port mapping is of the format `$scheme:$host_port:$container_port`. Supported schemes:

- grpc/grpcs: For grpc(s) proxying. Only labels that are explicitely called out are supported.
- tcp/udp: For stream proxying. Only labels that are explicitely called out are supported.
- http/https: For normal request proxying. Supports most labels unless otherwise specified.

#### `nginx.proxy-buffer-size`

Sets the size of the buffer proxy_buffer_size used for reading the first part of the response received from the proxied server. By default proxy buffer size is set as the pagesize.

#### `nginx.proxy-buffering`

Enable or disable proxy buffering proxy_buffering. By default proxy buffering is disabled in the NGINX config.

#### `nginx.proxy-buffers`

Sets the number of the buffers in proxy_buffers used for reading the first part of the response received from the proxied server. By default proxy buffers number is set as 4

#### `nginx.proxy-busy-buffer-size`

Sets the size of the buffer proxy_busy_buffer_size used for reading the first part of the response received from the proxied server. By default proxy busy buffer size is set as twice the pagesize.

#### `nginx.proxy-read-timeout`

Defines a timeout for reading a response from the proxied server.

#### `nginx.x-forwarded-for-value`

#### `nginx.x-forwarded-port-value`

#### `nginx.x-forwarded-proto-value`

#### `nginx.x-forwarded-ssl`

## TODO

- Add documentation for all labels
- Skip apps without domain
- Skip apps without proxy port mapping
