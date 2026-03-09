FROM        --platform=$TARGETOS/$TARGETARCH mcr.microsoft.com/dotnet/sdk:7.0

LABEL       author="STACloud" maintainer="congdongamazon@gmail.com"

LABEL       org.opencontainers.image.source="https://github.com/STA-Cloud-Dev/STACloudMultiEgg"
LABEL       org.opencontainers.image.licenses=MIT

ENV         DEBIAN_FRONTEND=noninteractive TZ=UTC

RUN         apt-get update -y \
    || ( . /etc/os-release \
    && if [ "$ID" = "debian" ]; then \
        if [ -f /etc/apt/sources.list ]; then sed -i 's|deb.debian.org|archive.debian.org|g; s|security.debian.org|archive.debian.org|g' /etc/apt/sources.list; fi; \
        find /etc/apt/sources.list.d -type f -exec sed -i 's|deb.debian.org|archive.debian.org|g; s|security.debian.org|archive.debian.org|g' {} +; \
        printf 'Acquire::Check-Valid-Until "false";\n' > /etc/apt/apt.conf.d/99stacloud-archive; \
      elif [ "$ID" = "ubuntu" ]; then \
        if [ -f /etc/apt/sources.list ]; then sed -i 's|archive.ubuntu.com|old-releases.ubuntu.com|g; s|security.ubuntu.com|old-releases.ubuntu.com|g' /etc/apt/sources.list; fi; \
        find /etc/apt/sources.list.d -type f -exec sed -i 's|archive.ubuntu.com|old-releases.ubuntu.com|g; s|security.ubuntu.com|old-releases.ubuntu.com|g' {} +; \
      fi \
    && apt-get update -y ) \
    && apt-get install -y --no-install-recommends bash ca-certificates curl ffmpeg git openssl sqlite3 tzdata \
    && rm -rf /var/lib/apt/lists/* \
    && useradd -d /home/container -m container

USER        container
ENV         USER=container HOME=/home/container
WORKDIR     /home/container

COPY        ./../entrypoint.sh /entrypoint.sh
CMD         [ "/bin/bash", "/entrypoint.sh" ]
