#!/usr/bin/env bats

export SYSTEM_NAME="$(uname -s | tr '[:upper:]' '[:lower:]')"
export TEST_CONTAINER_NAME="openresty-docker-proxy-$(shuf -i 2000-65000 -n 1)"

setup() {
  docker container rm -f "openresty-docker-proxy" || true
  docker image rm -f "openresty-docker-proxy:latest" || true
  if [[ -f "/tmp/cid-file" ]]; then
    docker container rm -f "$(cat /tmp/cid-file)" || true
    rm /tmp/cid-file
  fi
  if [[ -f "/tmp/cid-file-2" ]]; then
    docker container rm -f "$(cat /tmp/cid-file-2)" || true
    rm /tmp/cid-file-2
  fi
}

teardown() {
  docker container rm -f "openresty-docker-proxy" || true
  docker image rm -f "openresty-docker-proxy:latest" || true
  if [[ -f "/tmp/cid-file" ]]; then
    docker container rm -f "$(cat /tmp/cid-file)" || true
    rm /tmp/cid-file
  fi
  if [[ -f "/tmp/cid-file-2" ]]; then
    docker container rm -f "$(cat /tmp/cid-file-2)" || true
    rm /tmp/cid-file-2
  fi
}

@test "[build]" {
  run docker image build -t openresty-docker-proxy:latest .
  echo "output: $output"
  echo "status: $status"
  assert_success
}

@test "[start]" {
  run docker image build -t openresty-docker-proxy:latest .
  echo "output: $output"
  echo "status: $status"
  assert_success

  run docker container run -d -v /var/run/docker.sock:/var/run/docker.sock --name openresty-docker-proxy openresty-docker-proxy:latest
  echo "output: $output"
  echo "status: $status"
  assert_success

  sleep 3

  run docker inspect openresty-docker-proxy
  echo "output: $output"
  echo "status: $status"
  assert_success

  run docker logs openresty-docker-proxy
  echo "output: $output"
  echo "status: $status"
  assert_success

  run docker container rm -f openresty-docker-proxy
  echo "output: $output"
  echo "status: $status"
  assert_success
}

@test "[start] grpc" {
  run docker image build -t openresty-docker-proxy:latest .
  echo "output: $output"
  echo "status: $status"
  assert_success

  run docker container run -d -v /var/run/docker.sock:/var/run/docker.sock --name openresty-docker-proxy openresty-docker-proxy:latest
  echo "output: $output"
  echo "status: $status"
  assert_success

  run docker run --rm -d --cidfile /tmp/cid-file --platform linux/amd64 --label=openresty.domains=python.example.com --label=openresty.port-mapping=grpc:80:5000 --label=com.dokku.app-name=python --label=com.dokku.process-type=web --name "$TEST_CONTAINER_NAME" dokku/python-sample /start web
  echo "output: $output"
  echo "status: $status"
  assert_success

  sleep 3

  run docker logs openresty-docker-proxy
  echo "output: $output"
  echo "status: $status"
  assert_success

  IP_ADDRESS="$(docker container inspect --format='{{.NetworkSettings.IPAddress}}' "$TEST_CONTAINER_NAME")"
  run echo "$IP_ADDRESS"
  echo "output: $output"
  echo "status: $status"
  assert_success

  run docker exec -it openresty-docker-proxy cat /etc/nginx/sites-enabled/sites.conf
  echo "output: $output"
  echo "status: $status"
  assert_success
  assert_output_cr "$(sed "s/VAR_IP_ADDRESS/$IP_ADDRESS/" fixtures/grpc.tmpl)"
}

@test "[start] grpcs cert" {
  run docker image build -t openresty-docker-proxy:latest .
  echo "output: $output"
  echo "status: $status"
  assert_success

  run docker container run -d -v /var/run/docker.sock:/var/run/docker.sock --name openresty-docker-proxy openresty-docker-proxy:latest
  echo "output: $output"
  echo "status: $status"
  assert_success

  sleep 3

  run docker logs openresty-docker-proxy
  echo "output: $output"
  echo "status: $status"
  assert_success

  run docker container exec openresty-docker-proxy cp /etc/ssl/resty-auto-ssl-fallback.key /etc/nginx/ssl/python-server.key
  echo "output: $output"
  echo "status: $status"
  assert_success

  run docker container exec openresty-docker-proxy cp /etc/ssl/resty-auto-ssl-fallback.crt /etc/nginx/ssl/python-server.crt
  echo "output: $output"
  echo "status: $status"
  assert_success

  run docker run --rm --cidfile /tmp/cid-file --platform linux/amd64 --label=openresty.domains=python.example.com '--label=openresty.port-mapping=grpcs:443:5000' --label=com.dokku.app-name=python --label=com.dokku.process-type=web --name "$TEST_CONTAINER_NAME" -d dokku/python-sample /start web
  echo "output: $output"
  echo "status: $status"
  assert_success

  sleep 3

  run docker logs openresty-docker-proxy
  echo "output: $output"
  echo "status: $status"
  assert_success

  IP_ADDRESS="$(docker container inspect --format='{{.NetworkSettings.IPAddress}}' "$TEST_CONTAINER_NAME")"
  run echo "$IP_ADDRESS"
  echo "output: $output"
  echo "status: $status"
  assert_success

  run docker exec -it openresty-docker-proxy cat /etc/nginx/sites-enabled/sites.conf
  echo "output: $output"
  echo "status: $status"
  assert_success
  assert_output_cr "$(sed "s/VAR_IP_ADDRESS/$IP_ADDRESS/" fixtures/grpcs.cert.tmpl)"
}

@test "[start] grpcs letsencrypt" {
  run docker image build -t openresty-docker-proxy:latest .
  echo "output: $output"
  echo "status: $status"
  assert_success

  run docker container run -d -v /var/run/docker.sock:/var/run/docker.sock --name openresty-docker-proxy openresty-docker-proxy:latest
  echo "output: $output"
  echo "status: $status"
  assert_success

  run docker run --rm -d --cidfile /tmp/cid-file --platform linux/amd64 --label=openresty.domains=python.example.com '--label=openresty.port-mapping=grpcs:443:5000' --label=openresty.letsencrypt=true --label=com.dokku.app-name=python --label=com.dokku.process-type=web --name "$TEST_CONTAINER_NAME" dokku/python-sample /start web
  echo "output: $output"
  echo "status: $status"
  assert_success

  sleep 3

  run docker logs openresty-docker-proxy
  echo "output: $output"
  echo "status: $status"
  assert_success

  IP_ADDRESS="$(docker container inspect --format='{{.NetworkSettings.IPAddress}}' "$TEST_CONTAINER_NAME")"
  run echo "$IP_ADDRESS"
  echo "output: $output"
  echo "status: $status"
  assert_success

  run docker exec -it openresty-docker-proxy cat /etc/nginx/sites-enabled/sites.conf
  echo "output: $output"
  echo "status: $status"
  assert_success
  assert_output_cr "$(sed "s/VAR_IP_ADDRESS/$IP_ADDRESS/" fixtures/grpcs.letsencrypt.tmpl)"
}

@test "[start] http" {
  run docker image build -t openresty-docker-proxy:latest .
  echo "output: $output"
  echo "status: $status"
  assert_success

  run docker container run -d -v /var/run/docker.sock:/var/run/docker.sock --name openresty-docker-proxy openresty-docker-proxy:latest
  echo "output: $output"
  echo "status: $status"
  assert_success

  run docker run --rm -d --cidfile /tmp/cid-file --platform linux/amd64 --label=openresty.domains=python.example.com --label=openresty.port-mapping=http:80:5000 --label=com.dokku.app-name=python --label=com.dokku.process-type=web --name "$TEST_CONTAINER_NAME" dokku/python-sample /start web
  echo "output: $output"
  echo "status: $status"
  assert_success

  sleep 3

  run docker logs openresty-docker-proxy
  echo "output: $output"
  echo "status: $status"
  assert_success

  IP_ADDRESS="$(docker container inspect --format='{{.NetworkSettings.IPAddress}}' "$TEST_CONTAINER_NAME")"
  run echo "$IP_ADDRESS"
  echo "output: $output"
  echo "status: $status"
  assert_success

  run docker exec -it openresty-docker-proxy cat /etc/nginx/sites-enabled/sites.conf
  echo "output: $output"
  echo "status: $status"
  assert_success
  assert_output_cr "$(sed "s/VAR_IP_ADDRESS/$IP_ADDRESS/" fixtures/http.tmpl)"
}

@test "[start] https cert" {
  run docker image build -t openresty-docker-proxy:latest .
  echo "output: $output"
  echo "status: $status"
  assert_success

  run docker container run -d -v /var/run/docker.sock:/var/run/docker.sock --name openresty-docker-proxy openresty-docker-proxy:latest
  echo "output: $output"
  echo "status: $status"
  assert_success

  sleep 3

  run docker logs openresty-docker-proxy
  echo "output: $output"
  echo "status: $status"
  assert_success

  run docker container exec openresty-docker-proxy cp /etc/ssl/resty-auto-ssl-fallback.key /etc/nginx/ssl/python-server.key
  echo "output: $output"
  echo "status: $status"
  assert_success

  run docker container exec openresty-docker-proxy cp /etc/ssl/resty-auto-ssl-fallback.crt /etc/nginx/ssl/python-server.crt
  echo "output: $output"
  echo "status: $status"
  assert_success

  run docker run --rm --cidfile /tmp/cid-file --platform linux/amd64 --label=openresty.domains=python.example.com '--label=openresty.port-mapping=http:80:5000 https:443:5000' --label=com.dokku.app-name=python --label=com.dokku.process-type=web --name "$TEST_CONTAINER_NAME" -d dokku/python-sample /start web
  echo "output: $output"
  echo "status: $status"
  assert_success

  sleep 3

  run docker logs openresty-docker-proxy
  echo "output: $output"
  echo "status: $status"
  assert_success

  IP_ADDRESS="$(docker container inspect --format='{{.NetworkSettings.IPAddress}}' "$TEST_CONTAINER_NAME")"
  run echo "$IP_ADDRESS"
  echo "output: $output"
  echo "status: $status"
  assert_success

  run docker exec -it openresty-docker-proxy cat /etc/nginx/sites-enabled/sites.conf
  echo "output: $output"
  echo "status: $status"
  assert_success
  assert_output_cr "$(sed "s/VAR_IP_ADDRESS/$IP_ADDRESS/" fixtures/https.cert.tmpl)"
}

@test "[start] https letsencrypt" {
  run docker image build -t openresty-docker-proxy:latest .
  echo "output: $output"
  echo "status: $status"
  assert_success

  run docker container run -d -v /var/run/docker.sock:/var/run/docker.sock --name openresty-docker-proxy openresty-docker-proxy:latest
  echo "output: $output"
  echo "status: $status"
  assert_success

  run docker run --rm --cidfile /tmp/cid-file --platform linux/amd64 --label=openresty.domains=python.example.com '--label=openresty.port-mapping=http:80:5000 https:443:5000' --label=openresty.letsencrypt=true --label=com.dokku.app-name=python --label=com.dokku.process-type=web --name "$TEST_CONTAINER_NAME" -d dokku/python-sample /start web
  echo "output: $output"
  echo "status: $status"
  assert_success

  sleep 3

  run docker logs openresty-docker-proxy
  echo "output: $output"
  echo "status: $status"
  assert_success

  IP_ADDRESS="$(docker container inspect --format='{{.NetworkSettings.IPAddress}}' "$TEST_CONTAINER_NAME")"
  run echo "$IP_ADDRESS"
  echo "output: $output"
  echo "status: $status"
  assert_success

  run docker exec -it openresty-docker-proxy cat /etc/nginx/sites-enabled/sites.conf
  echo "output: $output"
  echo "status: $status"
  assert_success
  assert_output_cr "$(sed "s/VAR_IP_ADDRESS/$IP_ADDRESS/" fixtures/https.letsencrypt.tmpl)"

  run docker run --rm --cidfile /tmp/cid-file-2 --platform linux/amd64 '--label=openresty.domains=python2.example.com _' '--label=openresty.port-mapping=http:80:5000 https:443:5000' --label=openresty.letsencrypt=true --label=com.dokku.app-name=python2 --label=com.dokku.process-type=web --name "${TEST_CONTAINER_NAME}_2" -d dokku/python-sample /start web
  echo "output: $output"
  echo "status: $status"
  assert_success

  sleep 3

  IP_ADDRESS_2="$(docker container inspect --format='{{.NetworkSettings.IPAddress}}' "${TEST_CONTAINER_NAME}_2")"
  run echo "$IP_ADDRESS_2"
  echo "output: $output"
  echo "status: $status"
  assert_success

  run docker exec -it openresty-docker-proxy cat /etc/nginx/sites-enabled/sites.conf
  echo "output: $output"
  echo "status: $status"
  assert_success
  assert_output_cr "$(sed -e "s/VAR_IP_ADDRESS_1/$IP_ADDRESS/" -e "s/VAR_IP_ADDRESS_2/$IP_ADDRESS_2/" fixtures/https.letsencrypt-no-default.tmpl)"
}

assert_equal() {
  if [[ "$1" != "$2" ]]; then
    {
      echo "expected: $1"
      echo "actual: $2"
      echo "diff:"
      diff <(echo "$1") <(echo "$2")
    } | flunk
  fi
}

# ShellCheck doesn't know about $status from Bats
# shellcheck disable=SC2154
# shellcheck disable=SC2120
assert_failure() {
  if [[ "$status" -eq 0 ]]; then
    flunk "expected failed exit status"
  elif [[ "$#" -gt 0 ]]; then
    assert_output "$1"
  fi
}

# ShellCheck doesn't know about $output from Bats
# shellcheck disable=SC2154
assert_output() {
  local expected
  if [[ $# -eq 0 ]]; then
    expected="$(cat -)"
  else
    expected="$1"
  fi
  assert_equal "$expected" "$output"
}

# Compares output while removing carriage returns
# ShellCheck doesn't know about $output from Bats
# shellcheck disable=SC2154
assert_output_cr() {
  local expected
  if [[ $# -eq 0 ]]; then
    expected="$(cat -)"
  else
    expected="$1"
  fi
  assert_equal "$expected" "$(echo "$output" | tr -d '\r')"
}

# ShellCheck doesn't know about $output from Bats
assert_output_contains() {
  local input="$output"
  local expected="$1"
  local count="${2:-1}"
  local found=0
  until [ "${input/$expected/}" = "$input" ]; do
    input="${input/$expected/}"
    found=$((found + 1))
  done
  assert_equal "$count" "$found"
}

# ShellCheck doesn't know about $status from Bats
# shellcheck disable=SC2154
# shellcheck disable=SC2120
assert_success() {
  if [[ "$status" -ne 0 ]]; then
    flunk "command failed with exit status $status"
  elif [[ "$#" -gt 0 ]]; then
    assert_output "$1"
  fi
}

# test functions
flunk() {
  {
    if [[ "$#" -eq 0 ]]; then
      cat -
    else
      echo "$*"
    fi
  }
  return 1
}
