# Docker image for apprise using debian template
ARG LICENSE="MIT"
ARG IMAGE_NAME="apprise"
ARG PHP_SERVER="apprise"
ARG TIMEZONE="America/New_York"
ARG BUILD_DATE="Fri Feb 24 02:49:17 AM EST 2023"
ARG DEFAULT_DATA_DIR="/usr/local/share/template-files/data"
ARG DEFAULT_CONF_DIR="/usr/local/share/template-files/config"
ARG DEFAULT_TEMPLATE_DIR="/usr/local/share/template-files/defaults"

ARG SERVICE_PORT="8080"
ARG EXPOSE_PORTS="8025"
ARG PHP_VERSION=""
ARG NODE_VERSION="system"
ARG NODE_MANAGER="system"

ARG USER="root"
ARG DISTRO_VERSION="11"
ARG CONTAINER_VERSION="latest"
ARG IMAGE_VERSION="latest"
ARG BUILD_VERSION="${DISTRO_VERSION}"

FROM caronc/apprise:${IMAGE_VERSION} AS build
ARG USER
ARG LICENSE
ARG TIMEZONE
ARG IMAGE_NAME
ARG PHP_SERVER
ARG BUILD_DATE
ARG SERVICE_PORT
ARG EXPOSE_PORTS
ARG NODE_VERSION
ARG NODE_MANAGER
ARG BUILD_VERSION
ARG DEFAULT_DATA_DIR
ARG DEFAULT_CONF_DIR
ARG DEFAULT_TEMPLATE_DIR
ARG DISTRO_VERSION
ARG PHP_VERSION

ARG PACK_LIST="bash sudo tini iproute2 procps net-tools python3-pip"

ENV ENV=~/.bashrc
ENV LANG="en_US.UTF-8"
ENV LANGUAGE="en_US.UTF-8"
ENV TZ="America/New_York"
ENV SHELL="/bin/sh"
ENV TERM="xterm-256color"
ENV TIMEZONE="${TZ:-$TIMEZONE}"
ENV HOSTNAME="casjaysdev-apprise"
ENV DEBIAN_FRONTEND="noninteractive"

USER ${USER}
COPY ./rootfs/. /

RUN set -ex; \
  mkdir -p "${DEFAULT_DATA_DIR}" "${DEFAULT_CONF_DIR}" "${DEFAULT_TEMPLATE_DIR}" ; \
  apt-get update && apt-get install -yy locales && echo "$LANG UTF-8" >"/etc/locale.gen" ; \
  dpkg-reconfigure --frontend=noninteractive locales ; update-locale LANG=$LANG ; \
  echo 'export DEBIAN_FRONTEND="'${DEBIAN_FRONTEND}'"' >"/etc/profile.d/apt.sh" && chmod 755 "/etc/profile.d/apt.sh" && \
  DEBIAN_CODENAME="$(grep -s 'VERSION_CODENAME=' /etc/os-release | awk -F'=' '{print $2}')" ; \
  [ -z "$DEBIAN_CODENAME" ] || sed -i "s|$DEBIAN_CODENAME|$DISTRO_VERSION|g" "/etc/apt/sources.list" ; \
  apt-get update -yy && apt-get upgrade -yy && apt-get install -yy ${PACK_LIST}

RUN echo

RUN echo 'Running cleanup' ; \
  update-alternatives --install /bin/sh sh /bin/bash 1 ; \
  apt-get clean ; \
  rm -Rf /usr/share/doc/* /usr/share/info/* /tmp/* /var/tmp/* ; \
  rm -Rf /usr/local/bin/.gitkeep /config /data /var/lib/apt/lists/* ; \
  rm -rf /lib/systemd/system/multi-user.target.wants/* ; \
  rm -rf /etc/systemd/system/*.wants/* ; \
  rm -rf /lib/systemd/system/local-fs.target.wants/* ; \
  rm -rf /lib/systemd/system/sockets.target.wants/*udev* ; \
  rm -rf /lib/systemd/system/sockets.target.wants/*initctl* ; \
  rm -rf /lib/systemd/system/sysinit.target.wants/systemd-tmpfiles-setup* ; \
  rm -rf /lib/systemd/system/systemd-update-utmp* ; \
  if [ -d "/lib/systemd/system/sysinit.target.wants" ]; then cd "/lib/systemd/system/sysinit.target.wants" && rm $(ls | grep -v systemd-tmpfiles-setup) ; fi

FROM scratch
ARG USER
ARG LICENSE
ARG TIMEZONE
ARG IMAGE_NAME
ARG PHP_SERVER
ARG BUILD_DATE
ARG SERVICE_PORT
ARG EXPOSE_PORTS
ARG NODE_VERSION
ARG NODE_MANAGER
ARG BUILD_VERSION
ARG DEFAULT_DATA_DIR
ARG DEFAULT_CONF_DIR
ARG DEFAULT_TEMPLATE_DIR
ARG DISTRO_VERSION
ARG PHP_VERSION

USER ${USER}
WORKDIR /home/${USER}

LABEL maintainer="CasjaysDev <docker-admin@casjaysdev.com>"
LABEL org.opencontainers.image.vendor="CasjaysDev"
LABEL org.opencontainers.image.authors="CasjaysDev"
LABEL org.opencontainers.image.vcs-type="Git"
LABEL org.opencontainers.image.name="${IMAGE_NAME}"
LABEL org.opencontainers.image.base.name="${IMAGE_NAME}"
LABEL org.opencontainers.image.license="${LICENSE}"
LABEL org.opencontainers.image.vcs-ref="${BUILD_VERSION}"
LABEL org.opencontainers.image.build-date="${BUILD_DATE}"
LABEL org.opencontainers.image.version="${BUILD_VERSION}"
LABEL org.opencontainers.image.schema-version="${BUILD_VERSION}"
LABEL org.opencontainers.image.url="https://hub.docker.com/r/casjaysdevdocker/${IMAGE_NAME}"
LABEL org.opencontainers.image.vcs-url="https://github.com/casjaysdevdocker/${IMAGE_NAME}"
LABEL org.opencontainers.image.url.source="https://github.com/casjaysdevdocker/${IMAGE_NAME}"
LABEL org.opencontainers.image.documentation="https://hub.docker.com/r/casjaysdevdocker/${IMAGE_NAME}"
LABEL org.opencontainers.image.description="Containerized version of ${IMAGE_NAME}"
LABEL com.github.containers.toolbox="false"

ENV LANG=en_US.UTF-8
ENV ENV=~/.bashrc
ENV SHELL="/bin/bash"
ENV PORT="${SERVICE_PORT}"
ENV TERM="xterm-256color"
ENV PHP_SERVER="${PHP_SERVER}"
ENV PHP_VERSION="${PHP_VERSION}"
ENV NODE_VERSION="${NODE_VERSION}"
ENV NODE_MANAGER="${NODE_MANAGER}"
ENV CONTAINER_NAME="${IMAGE_NAME}"
ENV TZ="${TZ:-America/New_York}"
ENV TIMEZONE="${TZ:-$TIMEZONE}"
ENV HOSTNAME="casjaysdev-${IMAGE_NAME}"
ENV USER="${USER}"

COPY --from=build /. /

VOLUME [ "/config","/data" ]

EXPOSE $EXPOSE_PORTS

#CMD [ "" ]
ENTRYPOINT [ "tini", "-p", "SIGTERM", "--", "/usr/local/bin/entrypoint.sh" ]
HEALTHCHECK --start-period=1m --interval=2m --timeout=3s CMD [ "/usr/local/bin/entrypoint.sh", "healthcheck" ]
