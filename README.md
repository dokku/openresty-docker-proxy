# openresty-docker-proxy

Uses Openresty - an nginx-compatible server distribution - to proxy requests to other Docker containers based on configured labels.

## Usage

### Environment Variables

#### `OPENRESTY_APP_LABEL`

> default: `com.dokku.app-name`

An docker label to group server blocks by.

#### `OPENRESTY_DEBUG`

> default: `` (none)

Set to `true` to enable debugging comments in the generated config files.

#### `OPENRESTY_IGNORE_DEFAULT_DOMAIN`

> default: `true`

When `true`, all requests to a domain where there is a port listener will be ignored. Set to `false` to allow openresty to handle the default domain normally.

#### `OPENRESTY_LABEL_PREFIX`

> default: `openresty.`

The default prefix to use when looking up labels. All examples below assume the default label prefix.

#### `OPENRESTY_LETSENCRYPT_EMAIL`

> default: `` (none)

The email to use for enabling letsencrypt (required).

#### `OPENRESTY_LETSENCRYPT_CA`

> default: `https://acme-v02.api.letsencrypt.org/directory`

The certificate authority to use

#### `OPENRESTY_PROCESS_LABEL`

> default: `com.dokku.process-type`

A secondary docker label to group process types within servers by.

#### `OPENRESTY_WEB_PROCESS`

> default: `web`

The value of the `OPENRESTY_PROCESS_LABEL` that denotes the primary `web` process to proxy.

#### `OPENRESTY_DEFAULT_NETWORK`

> default: `bridge`

The default network to proxy requests to.

#### `OPENRESTY_OS_PAGESIZE`

> default: computed on container start

The default os page size to base default proxy values on.

### Labels

#### `openresty.access-log-format`

The format of the openresty access log for the app.

#### `openresty.access-log-path`

The path - in the container - where the access logs will be written.

#### `openresty.bind-address-ipv4`

The IPv4 address - in the container - openresty will bind to when proxying requests.

#### `openresty.bind-address-ipv6`

The IPv6 address - in the container - openresty will bind to when proxying requests.

#### `openresty.client-max-body-size`

The value of `client_max_body_size`, used for limiting file upload size.

#### `openresty.domains`

A space-delimited set of domains to proxy.

#### `openresty.error-log-path`

The path - in the container - where the error logs will be written.

#### `openresty.https-port`

Port treated as https when parsing port mappings.

#### `openresty.include-grpc-*`

#### `openresty.include-http-*`

#### `openresty.include-tcp-*`

#### `openresty.include-udp-*`

#### `openresty.initial-network`

The network name to use when proxying requests to the app container.

#### `openresty.letsencrypt`

When set to `true`, this enables dynamic SSL certificate provisioning via Let's Encrypt for any `https:443` port mappings. Note that the corresponding `http:80` port mapping must exist in order for this to succeed.

#### `openresty.port-mapping`

Holds a space-delimited set of port mappings, where the port mapping is of the format `$scheme:$host_port:$container_port`. Supported schemes:

- grpc/grpcs: For grpc(s) proxying. Only labels that are explicitely called out are supported.
- tcp/udp: For stream proxying. Only labels that are explicitely called out are supported.
- http/https: For normal request proxying. Supports most labels unless otherwise specified.

#### `openresty.proxy-buffer-size`

Sets the size of the buffer proxy_buffer_size used for reading the first part of the response received from the proxied server. By default proxy buffer size is set as the pagesize.

#### `openresty.proxy-buffering`

Enable or disable proxy buffering proxy_buffering. By default proxy buffering is disabled in the NGINX config.

#### `openresty.proxy-buffers`

Sets the number of the buffers in proxy_buffers used for reading the first part of the response received from the proxied server. By default proxy buffers number is set as 4

#### `openresty.proxy-busy-buffer-size`

Sets the size of the buffer proxy_busy_buffer_size used for reading the first part of the response received from the proxied server. By default proxy busy buffer size is set as twice the pagesize.

#### `openresty.proxy-connecting-timeout`

Defines a timeout for connect to a proxied server.

#### `openresty.proxy-read-timeout`

Defines a timeout for reading a response from the proxied server.

#### `openresty.proxy-send-timeout`

Defines a timeout for sending a request to the proxied server.

#### `openresty.send-timeout`

Defines a timeout for sending a response to the client.

#### `openresty.x-forwarded-for-value`

#### `openresty.x-forwarded-port-value`

#### `openresty.x-forwarded-proto-value`

#### `openresty.x-forwarded-ssl`

## TODO

- Add documentation for all labels
- Skip apps without domain
- Skip apps without proxy port mapping
