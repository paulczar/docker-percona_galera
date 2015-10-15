# This file creates a container that runs Database (Percona) with Galera Replication.
#
# Author: Paul Czarkowski
# Date: 08/16/2014

FROM debian:jessie
MAINTAINER Paul Czarkowski "paul@paulcz.net"

ENV PERCONA_VERSION=5.6 ETCD_VERSION=2.2.0 CONFD_VERSION=0.10.0 DEBIAN_FRONTEND=noninteractive

WORKDIR /tmp

# Base Deps
RUN \
  apt-key adv --keyserver keys.gnupg.net --recv-keys 1C4CBDCDCD2EFD2A && \
  echo "deb http://repo.percona.com/apt jessie main" > /etc/apt/sources.list.d/percona.list && \
  echo "deb-src http://repo.percona.com/apt jessie main" >> /etc/apt/sources.list.d/percona.list && \
  ln -fs /bin/true /usr/bin/chfn && \
  apt-get -yqq update && \
  apt-get install -yqq \
  ca-certificates \
  curl \
  vim-tiny \
  locales \
  runit \
  percona-xtradb-cluster-client-${PERCONA_VERSION} \
  percona-xtradb-cluster-server-${PERCONA_VERSION}  \
  percona-xtrabackup \
  percona-xtradb-cluster-garbd-3.x \
  --no-install-recommends && \
  locale-gen en_US.UTF-8 && \
  rm -rf /var/lib/apt/lists/* && \
  sed -i 's/^\(bind-address\s.*\)/# \1/' /etc/mysql/my.cnf && \
  rm -rf /var/lib/mysql/*

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

# Define mountable directories.
VOLUME ["/var/lib/mysql"]

ADD . /app

# Define working directory.
WORKDIR /app

RUN chmod +x /app/bin/*

# Define default command.
CMD ["/app/bin/boot"]

# Expose ports.
EXPOSE 3306 4444 4567 4568
