# -*- mode: cperl;-*-

use Test::More tests => 5;

use warnings;
use strict;

use Storable qw(dclone);

# First, lets create a dataset for the illustrious foo package

my %data = (package => q(foo),
	    found_versions   => ['bar/1.00',
				 '1.00',
				 '1.34',
				],
	    fixed_versions   => ['bar/1.02',
				 '1.45',
				],
	   );


use_ok('Debbugs::Status',qw(:versions));
# check removefoundversions
my $data = dclone(\%data);
removefoundversions($data,$data->{package},'1.00');
is_deeply($data->{found_versions},['1.34'],'removefoundversions removes all 1.00 versions');
$data = dclone(\%data);
removefoundversions($data,$data->{package},'bar/1.00');
is_deeply($data->{found_versions},['1.00','1.34'],'removefoundversions removes only bar/1.00 versions');
$data = dclone(\%data);
addfoundversions($data,$data->{package},'1.45');
is_deeply($data->{fixed_versions},['bar/1.02'],'addfoundversions removes fixed versions');
is_deeply($data->{found_versions},['bar/1.00',
				   '1.00',
				   '1.34',
				   'foo/1.45',
				  ],,'addfoundversions adds found versions');
