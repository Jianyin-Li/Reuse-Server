# Reuse-Server

Debian trixie 轻量跳板容器：Tailscale + Nginx，把一台机器复用成 tailnet 入口。
镜像里不含任何站点配置，默认不监听端口；站点由 `nginx/sites-enabled/` 外部提供。

## 特性

- Tailscale 无感接入：登录态持久化在卷 `reuse-ts-state`，重启/删容器/换镜像均不重登
- 首次可交互式登录（日志打印授权链接），无需事先准备 auth key
- TUN 模式，nginx 可反代 tailnet 内其他机器（MagicDNS 名字或 100.x）
- nginx 默认空跑：`sites-enabled` 为空时不启动，不占端口

## 构建与推送

```bash
cp .env.example .env
# 编辑 .env，把 IMAGE 设成你的 registry 地址
make build
make push
```

## 部署

```bash
git clone <repo> && cd Reuse-Server
cp .env.example .env          # 填 IMAGE
mkdir -p nginx/sites-enabled nginx/ssl
docker compose up -d
docker compose logs -f reuse-server
```

首次启动若打印登录链接，浏览器授权一次即可。授权后建议到后台
Machines → 该设备 → Disable key expiry，避免 180 天后需要重新登录。

## 加站点

参考 `examples/site.conf.example`，把 `*.conf` 放进 `nginx/sites-enabled/`，
证书放进 `nginx/ssl/`，然后：

```bash
docker compose exec reuse-server nginx          # nginx 未启动时先拉起
docker compose exec reuse-server nginx -s reload # 之后改配置只需 reload
```

## 备份与恢复节点身份

```bash
make backup

# 恢复
docker compose down
docker volume rm reuse-ts-state && docker volume create reuse-ts-state
docker run --rm -v reuse-ts-state:/d -v "$PWD/backup":/b alpine \
  sh -c 'tar xzf /b/reuse-ts-state-<时间>.tgz -C /d'
docker compose up -d
```

## 注意

- 同一份 `reuse-ts-state` 只能给一个容器使用。
- 切 `TS_USERSPACE=true` 时需同时去掉 compose 里的 `cap_add` / `devices` / `sysctls`。
- `TS_ACCEPT_DNS=true` 后容器 DNS 交给 tailnet；若 MagicDNS 未启用导致解析异常，
  改回 `false` 并把上游写成 `100.x` 形式。
