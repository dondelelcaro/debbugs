# -*- mode: cperl;-*-

use Test::More;

use warnings;
use strict;

use utf8;
use Encode;

# Default cmp '>'
my @versions = ({a      => '1.0-1',
		 b      => '2.0-2',
		 result => -1,
		 relation => 'lt',
		},
		{a      => '2.2~rc-4',
		 b      => '2.2-1',
		 result => -1,
		 relation => 'lt',
		},
		{a      => '2.2-1',
		 b      => '2.2~rc-4',
		 result => 1,
		 relation => 'gt',
		},
		{a      => '1.0000-1',
		 b      => '1.0-1',
		 result => 0,
		 relation => 'eq',
		},
		# q(1.1-20080727-1),q(1.1-20080316-1)
		{a      => '1.1-20080727-1',
		 b      => '1.1-20080316-1',
		 result => 1,
		 relation => 'gt',
		},
		{a      => '1.1-20080316-1',
		 b      => '1.1-20080727-1',
		 result => -1,
		 relation => 'lt',
		},
	       );

plan tests => @versions * 2 + 1;

sub dpkg_vercmp{
     my ($a,$b,$cmp) = @_;
     $cmp = 'gt' if not defined $cmp;
     return system('dpkg','--compare-versions',$a,$cmp,$b) == 0;
}


use_ok('Debbugs::Versions::Dpkg');

for my $version_cmp (@versions) {
     ok(Debbugs::Versions::Dpkg::vercmp($$version_cmp{a},$$version_cmp{b}) == $$version_cmp{result},
	"Version $$version_cmp{a} $$version_cmp{relation} $$version_cmp{b} ok");
     ok(dpkg_vercmp($$version_cmp{a},$$version_cmp{b},$$version_cmp{relation}),
	"Dpkg concures: Version $$version_cmp{a} $$version_cmp{relation} $$version_cmp{b}");
}

