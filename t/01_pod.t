# -*- mode: cperl; -*-
use Test::More;
eval "use Test::Pod 1.00";
plan skip_all => "Test::Pod 1.00 required for testing POD" if $@;
all_pod_files_ok(grep {$_ !~ /[~#]$/} all_pod_files((-e 'blib'?'blib':(qw(lib))),
                                                     (qw(bin cgi scripts))
                                                    ));
