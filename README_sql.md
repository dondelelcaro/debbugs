# Bringing up SQL for Debbugs

## Creation of database

Debbugs needs a postgresql database (≥ 9.4) with the debversion
extension installed. `apt-get install postgresql-9.5
postgreql-9.5-debversion` to install those two packages.

Then create a database and enable the debversion extension:

    echo 'create database debbugs' | psql;
    echo 'create extension debversion' | psql debbugs;
    
Debbugs also expects to be able to connect to databases using
a
[postgresql service definition](https://www.postgresql.org/docs/current/static/libpq-pgservice.html) which
defines the host, port, database, and any other connection information
which is needed. The default service is 'debbugs', but this can be
configured using `/etc/debbugs/config` or the `--service` option to
most commands. The most simplistic `~/.pg_service.conf` looks like this:

    [debbugs]
     host=localhost
     database=debbugs

## Insert database schema

To create the database schema, run `debbugs-installsql
--service=debbugs --install` (replacing debbugs with whatever the
appropriate service is.) The `debbugs-installsql` command also has an
`--upgrade` option which can be used to upgrade the schema between
schema revisions.

## Populate database initially

1. Insert configuration `debbugs-loadsql configuration`
2. Add suites `debbugs-loadsql suites --ftpdist /srv/ftp.debian.org/dists`
3. Add packages `debbugs-loadsql packages --progress --ftpdist /srv/ftp.debian.org/dists`
4. Add debinfo
   find /srv/bugs.debian.org/versions/archive/ftp-master -type f -iname '*.debinfo' -print0 \
   debbugs-loadsql --progress debinfo --null;
5. Add versions
   find /srv/bugs.debian.org/versions/archive/ftp-master -type f -iname '*.versions' -print0 \
   debbugs-loadsql --progress debinfo --null;
4. Add bugs `debbugs-loadsql bugs --progress --preload`
5. Add bug logs `debbugs-loadsql logs --progress`
6. Add maintainers `debbugs-loadsql maintainers`

