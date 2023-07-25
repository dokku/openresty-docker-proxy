#!/usr/bin/env bats

export SYSTEM_NAME="$(uname -s | tr '[:upper:]' '[:lower:]')"

setup_file() {
  docker container rm -f "nginx-docker-proxy" || true
  docker image rm -f "nginx-docker-proxy:latest" || true
  if [[ -f "/tmp/cid-file" ]]; then
    docker container rm -f "$(cat /tmp/cid-file)" || true
    rm /tmp/cid-file
  fi
}

teardown_file() {
  docker container rm -f "nginx-docker-proxy" || true
  docker image rm -f "nginx-docker-proxy:latest" || true
  if [[ -f "/tmp/cid-file" ]]; then
    docker container rm -f "$(cat /tmp/cid-file)" || true
    rm /tmp/cid-file
  fi
}

@test "[build]" {
  run docker image build -t nginx-docker-proxy:latest .
  echo "output: $output"
  echo "status: $status"
  assert_success
}

@test "[start]" {
  run docker image build -t nginx-docker-proxy:latest .
  echo "output: $output"
  echo "status: $status"
  assert_success

  run docker container run -d -v /var/run/docker.sock:/var/run/docker.sock --name nginx-docker-proxy nginx-docker-proxy:latest
  echo "output: $output"
  echo "status: $status"
  assert_success

  run docker inspect nginx-docker-proxy
  echo "output: $output"
  echo "status: $status"
  assert_success

  run docker logs nginx-docker-proxy
  echo "output: $output"
  echo "status: $status"
  assert_success

  sleep 2

  run docker container rm -f nginx-docker-proxy
  echo "output: $output"
  echo "status: $status"
  assert_success
}

@test "[start] config generation" {
  run docker image build -t nginx-docker-proxy:latest .
  echo "output: $output"
  echo "status: $status"
  assert_success

  run docker container run -d -v /var/run/docker.sock:/var/run/docker.sock --name nginx-docker-proxy nginx-docker-proxy:latest
  echo "output: $output"
  echo "status: $status"
  assert_success

  run docker run --rm -d --cidfile /tmp/cid-file --platform linux/amd64 --label=nginx.domains=derp.com --label=nginx.port-mapping=http:80:5000 --label=com.dokku.app-name=python --label=com.dokku.process-type=web -d dokku/python-sample /start web
  echo "output: $output"
  echo "status: $status"
  assert_success

  sleep 1

  run docker exec -it nginx-docker-proxy cat /etc/nginx/sites-enabled/sites.conf
  echo "output: $output"
  echo "status: $status"
  assert_success
  assert_output_contains "upstream python-web-5000"
  assert_output_contains "proxy_pass              http://python-web-5000;"
  assert_output_contains "server_name                 derp.com;"
  assert_output_contains "app=python process_type=web container_port=5000 network=bridge scheme=http"
}

assert_equal() {
  if [[ "$1" != "$2" ]]; then
    {
      echo "expected: $1"
      echo "actual:   $2"
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
