package Debbugs::Common; 

use strict;

BEGIN {
	use Exporter   ();
	use vars       qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

	# set the version for version checking
	$VERSION     = 1.00;

	@ISA         = qw(Exporter);
	@EXPORT      = qw( &fail );
	%EXPORT_TAGS = (  );     # eg: TAG => [ qw!name1 name2! ],

	# your exported package globals go here,
	# as well as any optionally exported functions
	@EXPORT_OK   = qw();
}

use vars      @EXPORT_OK;
use Debbugs::Config qw(%Globals);

sub fail
{
	print "$_[0]\n";
	exit 1;
}

1;
END { }       # module clean-up code here (global destructor)
