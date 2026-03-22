FROM node:24-bookworm

LABEL author="STACloud" maintainer="congdongamazon@gmail.com"
LABEL org.opencontainers.image.source="https://github.com/STA-Cloud-Dev/STACloudMultiEgg"
LABEL org.opencontainers.image.licenses=MIT

RUN apt-get update \
    && apt-get install -y --no-install-recommends bash ca-certificates curl git jq tini \
    && npm install -g openclaw@latest \
    && npm cache clean --force \
    && useradd -m -d /home/container container \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

COPY --chmod=755 entrypoint.sh /entrypoint.sh

USER container
ENV USER=container \
    HOME=/home/container \
    NODE_ENV=production \
    OPENCLAW_HOME=/home/container/.openclaw
WORKDIR /home/container

EXPOSE 18789

ENTRYPOINT ["/usr/bin/tini", "--", "/entrypoint.sh"]
