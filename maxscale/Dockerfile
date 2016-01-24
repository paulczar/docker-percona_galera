# This file creates a container that runs Database (Percona) with Galera Replication.
#
# Author: Paul Czarkowski
# Date: 08/16/2014

FROM debian:jessie
MAINTAINER Paul Czarkowski "paul@paulcz.net"

ENV MAXSCALE_VERSION=1.2.1 DEBIAN_FRONTEND=noninteractive ETCD_VERSION=2.2.0 CONFD_VERSION=0.10.0 MAXSCALE_HOME=/usr/local/skysql/maxscale

# Base Deps
RUN \
  apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 8167EE24 && \
  echo "deb http://downloads.mariadb.com/enterprise/6whk-mygr/mariadb-maxscale/${MAXSCALE_VERSION}/debian jessie main" > /etc/apt/sources.list.d/maxscale.list && \
  apt-get update -yqq && apt-get install -yqq \
  ca-certificates \
  curl \
  vim-tiny \
  maxscale \
  runit \
  --no-install-recommends && \
  rm -rf /var/lib/apt/lists/*

# download latest stable etcdctl
RUN \
  curl -sSL https://github.com/coreos/etcd/releases/download/v$ETCD_VERSION/etcd-v$ETCD_VERSION-linux-amd64.tar.gz \
    | tar xzf - \
    && cp etcd-v$ETCD_VERSION-linux-amd64/etcd /usr/local/bin/etcd \
    && cp etcd-v$ETCD_VERSION-linux-amd64/etcdctl /usr/local/bin/etcdctl \
    && rm -rf etcd-v$ETCD_VERSION-linux-amd64 \
    && chmod +x /usr/local/bin/etcd \
    && chmod +x /usr/local/bin/etcdctl

# install confd
RUN \
  curl -sSL https://github.com/kelseyhightower/confd/releases/download/v${CONFD_VERSION}/confd-${CONFD_VERSION}-linux-amd64 \
    -o /usr/local/bin/confd \
    && chmod +x /usr/local/bin/confd

COPY . /app

RUN chmod +x /app/bin/*

WORKDIR /app

EXPOSE 4006 4008

ENV SERVICE_4008_NAME=lb_read SERVICE_4006_NAME=lb_rw

CMD /app/bin/boot
