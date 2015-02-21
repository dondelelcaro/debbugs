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
      tags => 'wrongtag',
      order => 3,
     },
    {severity => 'critical',
     tags => 'second',
     order => 0,
    },
    {severity => 'normal',
     tags => 'third',
     order => 2,
    },
    );

for my $bug (@bugs) {
    my $order = Debbugs::CGI::Pkgreport::get_bug_order_index(\@usertags,$bug);
    ok($order == $bug->{order},
       "order $bug->{order} == $order",
      );
}


