#!/bin/bash
set -u

TS_STATE=/var/lib/tailscale/tailscaled.state
TS_SOCK=/var/run/tailscale/tailscaled.sock
SITES=/etc/nginx/sites-enabled
TS_NAME=${TS_HOSTNAME:-$(hostname)}

log() { echo "[entrypoint] $*"; }

# ---------- 1. tailscaled ----------
if [ "${TS_USERSPACE:-true}" = "true" ]; then
  TUN_ARGS="--tun=userspace-networking"
  log "网络模式: userspace（仅入站可达，容器内不能主动访问其他 TS 设备）"
else
  TUN_ARGS="--tun=tailscale0"
  log "网络模式: TUN（需 NET_ADMIN + /dev/net/tun）"
fi
[ -n "${TS_SOCKS_PORT:-}" ]      && TUN_ARGS="$TUN_ARGS --socks5-server=localhost:${TS_SOCKS_PORT}"
[ -n "${TS_HTTP_PROXY_PORT:-}" ] && TUN_ARGS="$TUN_ARGS --outbound-http-proxy-listen=localhost:${TS_HTTP_PROXY_PORT}"

tailscaled --state="$TS_STATE" --socket="$TS_SOCK" $TUN_ARGS ${TS_EXTRA_DAEMON_ARGS:-} &

for i in $(seq 1 40); do [ -S "$TS_SOCK" ] && break; sleep 0.5; done

# ---------- 2. nginx：只有存在站点配置才启动 ----------
mkdir -p "$SITES"
shopt -s nullglob
site_files=("$SITES"/*)
shopt -u nullglob
if [ ${#site_files[@]} -eq 0 ]; then
  log "sites-enabled 为空，nginx 不启动（放配置后执行: docker compose exec reuse-server nginx）"
else
  if nginx -t 2>/tmp/nginx-test.log; then
    nginx
    log "nginx 已启动，启用 ${#site_files[@]} 个站点"
  else
    log "nginx 配置检查失败，未启动："
    sed 's/^/    /' /tmp/nginx-test.log
  fi
fi

# ---------- 3. 登录状态判断（有登录态绝不重登） ----------
ts_json() { tailscale status --json 2>/dev/null | tr -d '\n\r'; }
backend_state() { ts_json | sed -n 's/.*"BackendState"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p'; }
auth_url()      { ts_json | sed -n 's/.*"AuthURL"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p'; }

state=""
for i in $(seq 1 20); do
  state=$(backend_state)
  [ -n "$state" ] && [ "$state" != "Starting" ] && break
  sleep 1
done
log "BackendState=$state"

case "$state" in
  Running)
    log "已登录，复用卷里的状态，跳过登录"
    ;;
  NeedsMachineAuth)
    log "已注册但等待管理员批准，请到后台 Machines 批准该设备"
    ;;
  *)
    if [ -n "${TS_AUTHKEY:-}" ]; then
      log "使用 auth key 登录"
      tailscale up --auth-key="$TS_AUTHKEY" --hostname="$TS_NAME" \
        --accept-dns="${TS_ACCEPT_DNS:-false}" ${TS_EXTRA_ARGS:-} \
        || log "登录失败（key 可能过期或已被使用）"
    else
      log "无 auth key，进入交互式登录"
      tailscale up --hostname="$TS_NAME" \
        --accept-dns="${TS_ACCEPT_DNS:-false}" ${TS_EXTRA_ARGS:-} \
        >/tmp/ts-up.log 2>&1 &
      printed=0
      for i in $(seq 1 150); do
        u=$(auth_url)
        if [ -n "$u" ] && [ "$printed" -eq 0 ]; then
          printed=1
          log "请用浏览器打开下面的链接完成登录（约 30 分钟有效）："
          echo ""; echo "    $u"; echo ""
        fi
        [ "$(backend_state)" = "Running" ] && { log "登录成功，状态已写入卷"; break; }
        sleep 2
      done
    fi
    ;;
esac

wait
