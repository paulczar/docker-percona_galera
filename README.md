# Auto Clustering/Replicating Percona Database

This is a tech demo of a combination of the [factorish](https://github.com/factorish/factorish) toolset to create
and run a Percona (mysql) Database image that when combined with
[etcd](https://coreos.com/etcd/) will
automatically cluster and replicate with itself.

## How does it work ?

There are two images in this project, the first contains Percona and the
Galera replication tools, the second contains Maxscale (a MySQL load balancer).

When run with access to a service discovery tool (`etcd` by default) it is
able discover other running databases and set up a replication relationship.

By default it uses Glider Labs'
[registrator](http://github.com/gliderlabs/registrator) to perform the service
registry, but can access `etcd` directly if that is your preference.

Inside the container `runit` manages three processes:

### confd

Used to watch the `etcd` endpoint and rewrite config files with any changes.

### healthcheck

Watches availability of the application ( percona or maxscale ) and kills
runit (thus the container) when it fails.

### percona / maxscale

Runs the main process for the container,  either Percona or Maxscale
depending on which image is running.

See [factorish](https://github.com/factorish/factorish) for a detailed description of the factorish toolset.

## Tech Demo

In order to demonstrate the clustering capabilties there is an included
`Vagrantfile` which when used will spin up a 3 node
[coreos](https://coreos.com) cluster
running a local [Docker Registry](https://www.docker.com/docker-registry)
and [Registrator](http://github.com/gliderlabs/registrator) images.

If you want to run this outside of the tech demo see the `contrib/` directory
and/or start the tech demo first and view the `/etc/profiles.d/functions.sh`
file in any of the `coreos` nodes.

The `registry` is hosted in a path mapped in from the host computer and
therefore is shared amongst the `coreos` nodes.  This means that any
images pushed to it from one host are immediately avaliable to all the
other hosts.

This allows for some intelligent image pulling/building to ensure that
only a single node has to do the heavy lifting.  See the `user-data.erb`
file for the scripts that allow this sharing of work.

Both the `database` and `maxscale` images are built from scratch automatically and started as the `coreos` nodes come online.  Thanks to the `registry` they will survive a `vagrant destroy` which means subsequent `vagrant up` will be
substantially faster.

### Running in CoreOS with etcd/registrator discovery

In order to use the tech demo simply run the following:

    $ git clone https://github.com/paulczar/docker-percona_galera.git
    $ cd docker-percona_galera
    $ vagrant up

Once Vagrant has brought up your three nodes you want to log in and watch the progress of the build using one of the provided helper functions:

    $ vagrant ssh core-01
    $ journal_database

This make take a few minutes if its the first time you've run this and the images aren't cached in the registry.  If you get bored you can also check out `journal_registry` and `journal_registrator` and watch them get pulled down and run.  It is also possible a different host will be elected to do the build, in which case you'll see it show as waiting for that host before it proceeds.

Once the database is online ( you'll see percona start and replication collect in the `journal_database` output ) you can connect to Maxscale via the helper function `mysql`:

    $ mysql
    mysql> select @@hostname;
    +--------------+
    | @@hostname   |
    +--------------+
    | a7575fd684eb |
    +--------------+

_the maxscale LB can take a while to find the service to loadbalance, and can also sometimes just fail.  I haven't worked out why yet._

or by connecting to the shell of the database container on the current host:

    $ database
    root@ecfd272af45e:/app# mysql
    mysql> select @@hostname;
    +--------------+
    | @@hostname   |
    +--------------+
    | ecfd272af45e |
    +--------------+

_notice the returned hostname is not the same in both queries, this is because the first was loadbalanced to the database on a different container_

### Helper functions

Each container started at boot has the following helper functions created
created in `/etc/profile.d/functions.sh` and autoloaded by the shell.
(examples shown below for `database` container)

* `database` - get shell in container.
* `kill_database` - kills the container, equivalent to `docker rm -f database`
* `build_database` - rebuilds the image
* `push_database` - pushs the image to registry
* `log_database` - connect to the docker log stream for that container
* `journal_database` - connect to the systemd journal for that container

They become very useful when combined:

    $ build_database && push_database
    $ kill_database && run_database && log_database

There is also the `mysql` function which will connect you via the local proxy to a percona server and a `cleanup` function which deletes the `/services`
namespace in `etcd`

Finally in the git repo is a `clean_registry` script which when run on the host will remove all images from the registry filesystem which is useful if you want to do a full rebuild from scratch.

## Running without service discovery:

### Server 1

change `HOST` to be the IP address of the server.

```
$ export HOST=172.17.8.101
$ docker run --detach \
  --name database01 \
  -e BOOTSTRAP=1 -e DEBUG=1 \
  -e MYSQL_PASS=password -e REP_PASS=replicate \
  -e HOST=$HOST -e SERVICE_DISCOVERY=env \
  -p $HOST:3306:3306 \
  -p $HOST:4444:4444 \
  -p $HOST:4567:4567 \
  -p $HOST:4568:4568 \
  paulczar/percona-galera
```

### Servers 2,3,etc

change `HOST` to be the IP address of the server, change `CLUSTER_MEMBERS` to be the IP of the first server.

```
$ export HOST=172.17.8.102
docker run -ti --rm \
  --name database02 \
  -e DEBUG=1 \
  -e MYSQL_PASS=password -e REP_PASS=replicate \
  -e CLUSTER_MEMBERS=172.17.8.101 \
  -e HOST=$HOST -e SERVICE_DISCOVERY=env \
  -p $HOST:3306:3306 \
  -p $HOST:4444:4444 \
  -p $HOST:4567:4567 \
  -p $HOST:4568:4568 \
  paulczar/percona-galera  bash
```

## Run in Rackspace's Carina Service:

Signup for [carina](https://app.getcarina.com)  and create a 3 node cluster.  Download and source the carina config files and get the carina binary as well.

_note this will leave the mysql and galera ports open to the whole of the service-net network_

we need to get the servicenet IP address of each node:

```
$ docker info
Containers: 7
Images: 6
Engine Version:
Role: primary
Strategy: spread
Filters: health, port, dependency, affinity, constraint
Nodes: 3
 bf76bea4-47ef-43ac-a7ae-67a6e6db15bf-n1: 172.99.65.11:42376
  └ Containers: 3
  └ Reserved CPUs: 0 / 12
  └ Reserved Memory: 0 B / 4.2 GiB
  └ Labels: executiondriver=native-0.2, kernelversion=3.18.21-1-rackos, operatingsystem=Debian GNU/Linux 7 (wheezy) (containerized), storagedriver=aufs
 bf76bea4-47ef-43ac-a7ae-67a6e6db15bf-n2: 172.99.65.12:42376
  └ Containers: 2
  └ Reserved CPUs: 0 / 12
  └ Reserved Memory: 0 B / 4.2 GiB
  └ Labels: executiondriver=native-0.2, kernelversion=3.18.21-1-rackos, operatingsystem=Debian GNU/Linux 7 (wheezy) (containerized), storagedriver=aufs
 bf76bea4-47ef-43ac-a7ae-67a6e6db15bf-n3: 172.99.65.13:42376
  └ Containers: 2
  └ Reserved CPUs: 0 / 12
  └ Reserved Memory: 0 B / 4.2 GiB
  └ Labels: executiondriver=native-0.2, kernelversion=3.18.21-1-rackos, operatingsystem=Debian GNU/Linux 7 (wheezy) (containerized), storagedriver=aufs
CPUs: 36
Total Memory: 12.6 GiB
Name: a892be77e40c
```

for each node we need to  get the servicenet ip:

```
$ NODES=$(docker info | grep Nodes | awk '{print $2}')
$ for (( i=1; i<=$NODES; i++ )); do
    docker run --rm --net=host --env constraint:node==*n$i racknet/ip service ipv4
  done
10.176.230.11
10.176.230.12
10.176.230.13
```

Start your first MySQL server:

```
$ docker run --detach \
  --name database01 \
  --env constraint:node==bf76bea4-47ef-43ac-a7ae-67a6e6db15bf-n1 \
  -e DEBUG=1 -e MYSQL_USER=admin \
  -e MYSQL_PASS=notthispassword -e REP_PASS=woopdedoo \
  -e HOST=10.176.230.11 -e SERVICE_DISCOVERY=env \
  -p 10.176.230.11:3306:3306 \
  -p 10.176.230.11:4444:4444 \
  -p 10.176.230.11:4567:4567 \
  -p 10.176.230.11:4568:4568 \
  paulczar/percona-galera
```

Second and third:

```
$ docker run -d \
  --name database02 \
  --env constraint:node==bf76bea4-47ef-43ac-a7ae-67a6e6db15bf-n2 \
  -e MYSQL_USER=admin \
  -e CLUSTER_MEMBERS=10.176.230.11 \
  -e MYSQL_PASS=notthispassword -e REP_PASS=woopdedoo \
  -e HOST=10.176.230.12 -e SERVICE_DISCOVERY=env \
  -p 10.176.230.12:3306:3306 \
  -p 10.176.230.12:4444:4444 \
  -p 10.176.230.12:4567:4567 \
  -p 10.176.230.12:4568:4568 \
  paulczar/percona-galera

$ docker run -d \
  --name database03 \
  --env constraint:node==bf76bea4-47ef-43ac-a7ae-67a6e6db15bf-n3 \
  -e MYSQL_USER=admin \
  -e CLUSTER_MEMBERS=10.176.230.11 \
  -e MYSQL_PASS=notthispassword -e REP_PASS=woopdedoo \
  -e HOST=10.176.230.13 -e SERVICE_DISCOVERY=env \
  -p 10.176.230.13:3306:3306 \
  -p 10.176.230.13:4444:4444 \
  -p 10.176.230.13:4567:4567 \
  -p 10.176.230.13:4568:4568 \
  paulczar/percona-galera  
```

wait a minute or so then check status:

```
docker exec -ti database01 mysql -e "SHOW STATUS LIKE 'wsrep_cluster%'"
+--------------------------+--------------------------------------+
| Variable_name            | Value                                |
+--------------------------+--------------------------------------+
| wsrep_cluster_conf_id    | 3                                    |
| wsrep_cluster_size       | 3                                    |
| wsrep_cluster_state_uuid | 2882bcb7-ab3b-11e5-ab75-2b510ef0ec6f |
| wsrep_cluster_status     | Primary                              |
+--------------------------+--------------------------------------+
```

Author(s)
======

Paul Czarkowski (paul@paulcz.net)

License
=====

Copyright 2014 Paul Czarkowski
Copyright 2015 Paul Czarkowski

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
