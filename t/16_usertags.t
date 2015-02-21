# -*- mode: cperl;-*-

use Test::More;

use warnings;
use strict;

plan tests => 4;

use_ok('Debbugs::CGI::Pkgreport');

my @usertags = ('severity=serious,severity=grave,severity=critical',
                'tag=second',
                'tag=third',
                '',
               );

my @bugs =
    ({severity => 'normal',
      tag => 'wrongtag',
      order => 3,
     },
    {severity => 'critical',
     tag => 'second',
     order => 0,
    },
    {severity => 'normal',
     tag => 'third',
     order => 2,
    },
    );

for my $bug (@bugs) {
    ok(Debbugs::CGI::Pkgreport::get_bug_order_index(\@usertags,$bug) == $bug->{order},
       "order is actually $bug->{order}",
      );
}


