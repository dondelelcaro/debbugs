#!/bin/sh

if [ -z "$DEBBUGS_SERVICE" ]; then
    DEBBUGS_SERVICE="debbugs";
fi;

if ! [ -d "sql" ] || ! [ -d "Debbugs" ]; then 
    echo "In the wrong directory"
    exit 1;
fi;

dbicdump -I. -o dump_directory=. \
    -o components='["InflateColumn::DateTime","TimeStamp"]' \
    -o preserve_case=1 \
    -o skip_load_external=1 \
    -o exclude='qr/^dbix_class_deploymenthandler_versions$/' \
    Debbugs::DB dbi:Pg:service=$DEBBUGS_SERVICE '' '';

