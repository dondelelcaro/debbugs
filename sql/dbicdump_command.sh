#!/bin/sh

if [ -z "$DEBBUGS_SERVICE" ]; then
    DEBBUGS_SERVICE="debbugs";
fi;

if ! [ -d "sql" ] || ! [ -d "Debbugs" ]; then 
    echo "In the wrong directory"
    exit 1;
fi;

dbicdump -I. -o dump_directory=. \
    -o components='["InflateColumn::DateTime"]' \
    -o preserve_case=1 \
    Debbugs::DB dbi:Pg:service=$DEBBUGS_SERVICE '' '';

