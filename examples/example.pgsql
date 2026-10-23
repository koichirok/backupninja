### backupninja PostgreSQL config file ###

### optional command transport ###
# Database commands normally run locally. To run them in a container, add one
# of the following sections. backupdir is the path inside the container.
# Set hostbackupdir to copy the completed backup to the host; otherwise the
# container path should be backed by a host-visible volume. The copy only
# happens when every dump succeeded, and files on the host are replaced only
# after the whole transfer succeeded. Commands can run as root (the handler
# switches to PGSQLUSER) or directly as PGSQLUSER with transport user set.
# Container environment and workdir are retained, including when switching
# users. A different non-root user cannot switch to PGSQLUSER.
#
# Example for a Mattermost database in a read-only postgres:*-alpine
# container started with POSTGRES_USER=mmuser and POSTGRES_DB=mattermost,
# with a writable tmpfs on /tmp:
#
# backupdir = /tmp/backups/mattermost
# databases = mattermost
# dbusername = mmuser
# compress = no
#
# [transport]
# transport = podman
# container = mattermost-db
# hostbackupdir = /var/backups/mattermost
#
# This writes /var/backups/mattermost/mattermost.sql on the host.
#
# Other transports:
#
# [transport]
# transport = docker
# container = postgres
# hostbackupdir = /var/backups/postgres
#
# [transport]
# transport = podman
# container = postgres
# workdir = /var/lib/postgresql
# environment = NAME=value
# Use environment only for non-secret values (runtime command-line options).
# hostbackupdir = /var/backups/postgres
#
# [transport]
# transport = docker-compose
# projectdir = /srv/application
# service = postgres
# hostbackupdir = /var/backups/postgres

# backupdir = <dir> (default: /var/backups/postgres)
# where to dump the backups. With a container transport this is the path
# inside the container; use a writable temporary location such as /tmp/...
# for read-only containers and set hostbackupdir in [transport].

# dbusername = <role> (default: empty)
# PostgreSQL role used to connect (passed as -U to pg_dump, pg_dumpall and
# psql). The commands still run as the system user PGSQLUSER. When empty, no
# role is passed and the role defaults to the name of PGSQLUSER, as before.
# Set this when the database role differs from the system user, e.g. for the
# official postgres images with POSTGRES_USER set.

# databases = < all | db1 db2 db3 > (default = all)
# which databases to backup. should either be the word 'all' or a
# space separated list of database names.
# Note: when using 'all', pg_dumpall is used instead of pg_dump, which means
# that cluster-wide data (such as users and groups) are saved.

# compress = < yes | no > (default = yes)
# if yes, compress the pg_dump/pg_dumpall output.

# format = < plain | tar | custom > (default = plain)
# plain -  Output a plain-text SQL script file with the extension .sql.
#          When dumping all databases, a single file is created via pg_dumpall.
# tar -    Output a tar archive suitable for input into pg_restore. More
#          flexible than plain and can be manipulated by standard Unix tools
#          such as tar. Creates a globals.sql file and an archive per database.
# custom - Output a custom PostgreSQL pg_restore archive. This is the most
#          flexible format allowing selective import and reordering of database
#          objects at the time the database is restored via pg_restore. This
#          option creates a globals.sql file containing the cluster role and
#          other information dumped by pg_dumpall -g and a pg_restore file
#          per selected database. See the pg_dump and pg_restore man pages.

### You can also set the following variables in /etc/backupninja.conf:
# PGSQLDUMP: pg_dump path (default: /usr/bin/pg_dump)
# PGSQLDUMPALL: pg_dumpall path (default: /usr/bin/pg_dumpall)
# PGSQLUSER: system user running the dumps (default: postgres)
# PSQL: psql path (default: /usr/bin/psql)
# If PGSQLDUMP, PGSQLDUMPALL, PSQL or GZIP is not found at the configured path
# in the target, the same command name is looked up in the target's PATH.
# GZIP_OPTS that the target's gzip does not support (e.g. --rsyncable with
# BusyBox gzip) are dropped with a warning.
