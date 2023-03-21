#!/usr/bin/env bash

set -e

REPO="${LOCALDEV_REPO:-/repo}"

${REPO}/scripts/ext/stop.sh

k3d cluster stop localdev

# Ignore the result of the following command
set +e
RS=$(docker container stop dxp-server localdev-dnsmasq localdev-extension-runtime >/dev/null 2>&1)

echo "'localdev' runtime environment stopped."