FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        curl \
        jq \
        unzip \
        tzdata \
        tini \
        tar \
        gzip \
        nodejs \
        npm \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

ENV TZ=UTC
ENV RUNTIME_ROOT=/home/container/.local/share/stacloud/runtime
ENV JAVA_CACHE_DIR=/home/container/.local/share/stacloud/runtime/java
ENV JAVA_HOME=/home/container/.local/share/stacloud/runtime/java/temurin-21-jdk
ENV PATH="${JAVA_HOME}/bin:${PATH}"

WORKDIR /home/container

COPY entrypoint.sh /entrypoint.sh
COPY t.sh mc-java.sh mc-bedrock.sh mc-proxy.sh /opt/stacloud/
RUN chmod +x /entrypoint.sh /opt/stacloud/*.sh

ENTRYPOINT ["/usr/bin/tini", "--", "/entrypoint.sh"]

