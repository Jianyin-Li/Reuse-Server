FROM debian:trixie

ENV DEBIAN_FRONTEND=noninteractive

# 构建阶段：清华 IPv6-only 源
RUN sed -i 's|deb.debian.org|mirrors6.tuna.tsinghua.edu.cn|g; s|security.debian.org|mirrors6.tuna.tsinghua.edu.cn|g' /etc/apt/sources.list.d/debian.sources

# 基础依赖 + nginx + openssl
RUN apt-get update && apt-get install -y --no-install-recommends \
      curl gpg ca-certificates nginx openssl procps \
    && rm -rf /var/lib/apt/lists/*

# Tailscale 官方源（强制 IPv6，避开 IPv4 403）
RUN curl -6 -fsSL https://pkgs.tailscale.com/stable/debian/trixie.noarmor.gpg \
      -o /usr/share/keyrings/tailscale-archive-keyring.gpg \
 && echo "deb [signed-by=/usr/share/keyrings/tailscale-archive-keyring.gpg] https://pkgs.tailscale.com/stable/debian trixie main" \
      > /etc/apt/sources.list.d/tailscale.list \
 && apt-get -o Acquire::ForceIPv6=true update \
 && apt-get -o Acquire::ForceIPv6=true install -y --no-install-recommends tailscale \
 && rm -rf /var/lib/apt/lists/*

# 运行目录；清空默认站点，保证 nginx 默认"啥也不干"
RUN mkdir -p /var/lib/tailscale /var/run/tailscale /run/nginx /etc/nginx/ssl /etc/nginx/sites-enabled \
 && rm -f /etc/nginx/sites-enabled/* /etc/nginx/sites-available/default

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# 收尾：换回清华双栈源
RUN sed -i 's|mirrors6.tuna.tsinghua.edu.cn|mirrors.tuna.tsinghua.edu.cn|g' /etc/apt/sources.list.d/debian.sources

EXPOSE 80/tcp 443/tcp
ENTRYPOINT ["/entrypoint.sh"]
