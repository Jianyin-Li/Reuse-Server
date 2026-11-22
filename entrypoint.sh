#!/bin/bash
set -e

nginx

tailscaled \
  --state=/var/lib/tailscale/tailscaled.state \
  --socket=/var/run/tailscale/tailscaled.sock \
  --tun=userspace-networking &

for i in $(seq 1 20); do
  [ -S /var/run/tailscale/tailscaled.sock ] && break
  sleep 0.5
done

if [ -n "$TS_AUTHKEY" ]; then
  tailscale up \
    --authkey="$TS_AUTHKEY" \
    --hostname="${TS_HOSTNAME:-$(hostname)}" \
    ${TS_EXTRA_ARGS:-}
fi

wait
