Percona/Galera Docker Image
===========================

This docker image contains Percona with the galera extentions and XtraBackup installed.

If etcd is available it will automatically cluster itself with Galera and the XtraBackup SST.

Fetching
========

    $ git clone https://github.com/paulczar/docker-percona_galera.git
    cd docker-percona_galera

Building
========

    $ docker build -t paulczar/percona-galera .

Running
=======

Just a database
---------------

MySQL root user is available from localhost without a password.  a default user/pass pair of admin/admin is pulled in from environment variables which has root like perms.  set it to something sensible.

	 $ docker run -d -e MYSQL_USER=admin -e MYSQL_PASS=lolznopass paulczar/percona-galera
	  ==> $HOST not set.  booting mysql without clustering.
	  ==> An empty or uninitialized database is detected in /var/lib/mysql
    ==> Creating database...
    ==> Done!
    ==> starting mysql in order to set up passwords
    ==> sleeping for 20 seconds, then testing if DB is up
    140920 16:22:26 mysqld_safe Logging to '/var/log/mysql/error.log'.
    140920 16:22:26 mysqld_safe Starting mysqld daemon with databases from /var/lib/mysql
    140920 16:22:26 mysqld_safe Skipping wsrep-recover for empty datadir: /var/lib/mysql
    140920 16:22:26 mysqld_safe Assigning 00000000-0000-0000-0000-000000000000:-1 to wsrep_start_position
    ==> stopping mysql after setting up passwords
    140920 16:22:47 mysqld_safe mysqld from pid file /var/run/mysqld/mysqld.pid ended
    140920 16:22:48 mysqld_safe Logging to '/var/log/mysql/error.log'.
    140920 16:22:48 mysqld_safe Starting mysqld daemon with databases from /var/lib/mysql
    140920 16:22:48 mysqld_safe Skipping wsrep-recover for empty datadir: /var/lib/mysql
    140920 16:22:48 mysqld_safe Assigning 00000000-0000-0000-0000-000000000000:-1 to wsrep_start_position

Galera Cluster
--------------

When etcd is available the container will check to see if there's an existing cluster, if so it will join it.  If not it will perform an election that will last for 5 minutes.  During that time the first server that can grab a lock becomes the leader and any other nodes will wait until that server is ready before starting.   If the leader fails to start the election is busted and all nodes will need to be destroyed until the 5 minutes passes.

An example Vagrantfile is provided which will start a 3 node `CoreOS` cluster each node running a
database with replication automatically set up.

    $ vagrant up
    $ ssh coreos-01
    $ watch docker ps

At this point the coreos user-data is starting the database.  It has to be downloaded from the docker hub first, and this can take some time.   Eventually the container will start and you'll see this in the console:

    CONTAINER ID        IMAGE                            COMMAND             CREATED              STATUS              PORTS                                                                                            NAMES
    912ad42a4d1a        paulczar/percona-galera:latest   "/app/bin/boot"     About a minute ago   Up About a minute   0.0.0.0:3306->3306/tcp, 0.0.0.0:4444->4444/tcp, 0.0.0.0:4567->4567/tcp, 0.0.0.0:4568->4568/tcp   database

Next we can watch mysql starting by utilizing `journalctl`

    $ journalctl -f -u database
    Sep 20 18:54:36 core-01 sh[1489]: Starting MySQL for reals
    Sep 20 18:54:36 core-01 sh[1489]: ==> Performing Election...
    Sep 20 18:54:36 core-01 sh[1489]: -----> Hurruh I win!
    Sep 20 18:54:36 core-01 sh[1489]: ==> sleeping for 20 seconds, then testing if DB is up.
    Sep 20 18:54:36 core-01 sh[1489]: 140920 18:54:36 mysqld_safe Logging to '/var/lib/mysql/912ad42a4d1a.err'.
    Sep 20 18:54:36 core-01 sh[1489]: 140920 18:54:36 mysqld_safe Starting mysqld daemon with databases from /var/lib/mysql
    Sep 20 18:54:36 core-01 sh[1489]: 140920 18:54:36 mysqld_safe Skipping wsrep-recover for 82f9ad85-40f7-11e4-9f0d-1eed76224be8:0 pair
    Sep 20 18:54:36 core-01 sh[1489]: 140920 18:54:36 mysqld_safe Assigning 82f9ad85-40f7-11e4-9f0d-1eed76224be8:0 to wsrep_start_position
    Sep 20 18:54:56 core-01 sh[1489]: ==> database running...

At this point we can actually console into the container by running `database` which is a function we inject in the user-data to use `nsenter` to get a shell inside the database container...


    $ database
    root@e9682b05cf5e:/# mysql -e "show status like 'wsrep_cluster%'"
    +--------------------------+--------------------------------------+
    | Variable_name            | Value                                |
    +--------------------------+--------------------------------------+
    | wsrep_cluster_conf_id    | 3                                    |
    | wsrep_cluster_size       | 3                                    |
    | wsrep_cluster_state_uuid | 1b92a583-40f6-11e4-ad62-46aacd6cd67e |
    | wsrep_cluster_status     | Primary                              |
    +--------------------------+--------------------------------------+

There are some hints that you need to pass via environment variables to make this magic happen.
These are provided in the `database` unit in `user-data.erb`. Explore `user-data.erb`, `bin/boot`, and `bin/functions` to see how the sausage is made.

### cluster hints

These are the only madatory ones.  the rest default to sensible values.

* HOST - set this to the Host IP that you want to publish as your endpoint.
* ETCD_HOST - set if the etcd endpoint is different to the Host IP above.


GarbD
-----

If you want to stick to a two node cluster you can start garbd to act as the arbiter.

    $ eval `cat /etc/environment`
    $ /usr/bin/docker run --name database-garbd --rm -p 3306:3306 -p 4444:4444 -p 4567:4567 -p 4568:4568 -e PUBLISH=4567 -e HOST=$COREOS_PRIVATE_IPV4 -e CLUSTER=openstack paulczar/percona-galera:latest /app/bin/garbd

Load Balancer
-------------

You can use an external load balancer if you have one DB per host.  If you're getting fancy you can also run a local haproxy load balancer ( or multiples ) which will load balance ( round robin, nothing fancy ) database connections between your nodes

    $ eval `cat /etc/environment`
    $ /usr/bin/docker run --name database-loadbalancer --rm -p 3307:3307 -p 8888:8080 -e PUBLISH=3307 -e HOST=$COREOS_PRIVATE_IPV4 paulczar/percona-galera:latest /app/bin/loadbalancer

Development
-----------

You can use vagrant in developer mode which will install the service but not run it.  it will also enable debug mode on the start script, share the local path into `/home/coreos/share` via `nfs` and build the image locally.   This takes quite a while as it builds the image on each VM, but once its up further rebuilds should be quick thanks to the caches.

    $ dev=1 vagrant up
    $ vagrant ssh core-01


Author(s)
======

Paul Czarkowski (paul@paulcz.net)

License
=====

Copyright 2014 Paul Czarkowski

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
