docker-gen: docker-gen-wrapper -config /app/config.toml
nginx: openresty -g 'daemon off;' -c /etc/nginx/nginx.conf
logrotate: run-logrotate
