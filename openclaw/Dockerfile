FROM node:24-bookworm

LABEL author="STACloud" maintainer="congdongamazon@gmail.com"
LABEL org.opencontainers.image.source="https://github.com/STA-Cloud-Dev/STACloudMultiEgg"
LABEL org.opencontainers.image.licenses=MIT

RUN apt-get update \
    && apt-get install -y --no-install-recommends bash ca-certificates curl git jq tini \
    && useradd -m -d /home/container container \
    && mkdir -p /opt/openclaw-global /opt/openclaw-cache \
    && chown -R container:container /home/container /opt/openclaw-global /opt/openclaw-cache \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

COPY --chmod=755 entrypoint.sh /entrypoint.sh

USER container
ENV USER=container \
    HOME=/home/container \
    NODE_ENV=production \
    OPENCLAW_HOME=/home/container/.openclaw \
    OPENCLAW_STATE_DIR=/home/container/.openclaw \
    OPENCLAW_CONFIG_PATH=/home/container/.openclaw/openclaw.json \
    XDG_CONFIG_HOME=/home/container/.config \
    NPM_CONFIG_PREFIX=/opt/openclaw-global \
    NPM_CONFIG_CACHE=/opt/openclaw-cache \
    PATH=/opt/openclaw-global/bin:${PATH}
WORKDIR /home/container

RUN npm install -g openclaw@latest \
    && npm cache clean --force

EXPOSE 18789

ENTRYPOINT ["/usr/bin/tini", "--", "/entrypoint.sh"]
