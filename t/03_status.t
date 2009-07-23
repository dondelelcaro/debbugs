# -*- mode: cperl;-*-

use Test::More tests => 6;

use warnings;
use strict;

use utf8;
use Encode;

use_ok('Debbugs::Status');

my $data = {package => 'foo, bar, baz',
	    blocks  => '1 2 3',
	    blockedby => '',
	    tags      => 'foo, bar  , baz',
	   };

my @temp = Debbugs::Status::split_status_fields($data);
is_deeply($temp[0]{package},[qw(foo bar baz)],
	  'split_status_fields splits packages properly',
	 );
is_deeply($temp[0]{blocks},[qw(1 2 3)],
	  'split_status_fields splits blocks properly',
	 );
is_deeply($temp[0]{blockedby},[],
	  'split_status_fields handles empty fields properly',
	 );
is_deeply($temp[0]{tags},[qw(foo bar baz)],
	  'split_status_fields splits tags properly',
	 );
my $temp = Debbugs::Status::split_status_fields($data);
is_deeply(Debbugs::Status::split_status_fields($temp),$temp,
	  'recursively calling split_status_fields returns the same thing');
