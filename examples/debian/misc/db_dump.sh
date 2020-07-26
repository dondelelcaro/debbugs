#!/bin/sh

set -e

cd /srv/bugs.debian.org/www/db_dump;

DUMP_TIME=$(date +%Y%m%d_%H%M)

# We should be run at the lowest priority
ionice -c 3 -p $$ > /dev/null 2>&1
renice -n 19 -p $$ > /dev/null 2>&1

pg_dump --data-only --disable-triggers service=debbugs 2>/dev/null | \
    gzip -c > debbugs_dump_${DUMP_TIME}.gz

ln -sf debbugs_dump_${DUMP_TIME}.gz debbugs_dump_current.gz

# delete any dumps older than 4 days
find . -maxdepth 1 -mindepth 1 -type f -iname 'debbugs_dump_*.gz' \
     -ctime +4 -delete

