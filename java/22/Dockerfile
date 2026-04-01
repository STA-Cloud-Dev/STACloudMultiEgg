FROM        --platform=$TARGETOS/$TARGETARCH eclipse-temurin:22-jre-jammy

LABEL       author="STACloud" maintainer="congdongamazon@gmail.com"

LABEL       org.opencontainers.image.source="https://github.com/STA-Cloud-Dev/STACloudMultiEgg"
LABEL       org.opencontainers.image.licenses=MIT

ENV         DEBIAN_FRONTEND=noninteractive TZ=UTC

RUN         apt-get update -y \
	&& apt-get install -y --no-install-recommends bash ca-certificates curl ffmpeg git openssl sqlite3 tzdata \
	&& rm -rf /var/lib/apt/lists/* \
	&& useradd -d /home/container -m container

USER        container
ENV         USER=container HOME=/home/container
WORKDIR     /home/container

COPY        ./../entrypoint.sh /entrypoint.sh
CMD         [ "/bin/bash", "/entrypoint.sh" ]
