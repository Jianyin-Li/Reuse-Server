FROM debian:trixie

ENV DEBIAN_FRONTEND=noninteractive

# 1. 构建阶段：换成清华 IPv6-only 源，保证容器内能拉包
RUN sed -i 's|deb.debian.org|mirrors6.tuna.tsinghua.edu.cn|g; s|security.debian.org|mirrors6.tuna.tsinghua.edu.cn|g' /etc/apt/sources.list.d/debian.sources

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl gpg ca-certificates nginx \
    && rm -rf /var/lib/apt/lists/*

RUN curl -6 -fsSL https://pkgs.tailscale.com/stable/debian/trixie.noarmor.gpg \
      -o /usr/share/keyrings/tailscale-archive-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/tailscale-archive-keyring.gpg] https://pkgs.tailscale.com/stable/debian trixie main" \
      > /etc/apt/sources.list.d/tailscale.list \
    && apt-get -o Acquire::ForceIPv6=true update \
    && apt-get -o Acquire::ForceIPv6=true install -y --no-install-recommends tailscale \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /var/lib/tailscale /var/run/tailscale /run/nginx

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# 2. 收尾阶段：换回清华双栈源，作为最终镜像的默认 apt 源
RUN sed -i 's|mirrors6.tuna.tsinghua.edu.cn|mirrors.tuna.tsinghua.edu.cn|g' /etc/apt/sources.list.d/debian.sources

EXPOSE 80/tcp
ENTRYPOINT ["/entrypoint.sh"]
