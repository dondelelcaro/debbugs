#!/bin/sh

if ! [ -d "sql" ] || ! [ -d "Debbugs" ]; then 
    echo "In the wrong directory"
    exit 1;
fi;

dbicdump -I. -o dump_directory=. \
    -o components='["InflateColumn::DateTime"]' \
    -o preserve_case=1 \
    Debbugs::DB dbi:Pg:service=debbugs '' '';

