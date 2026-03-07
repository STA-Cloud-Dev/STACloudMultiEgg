

FROM        --platform=$TARGETOS/$TARGETARCH python:3.11-alpine

LABEL       author="STACloud" maintainer="congdongamazon@gmail.com"

LABEL       org.opencontainers.image.source="https://github.com/STA-Cloud-Dev/STACloudMultiEgg"
LABEL       org.opencontainers.image.licenses=MIT

RUN         apk add --update --no-cache bash cmake make ca-certificates curl ffmpeg g++ gcc gettext git openssl sqlite tar tzdata \
	&& adduser -D -h /home/container container

USER        container
ENV         USER=container HOME=/home/container
WORKDIR     /home/container

COPY        ./../entrypoint.sh /entrypoint.sh
CMD         [ "/bin/bash", "/entrypoint.sh" ]
