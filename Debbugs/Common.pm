package Debbugs::Common; 

use strict;

BEGIN {
	use Exporter   ();
	use vars       qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

	# set the version for version checking
	$VERSION     = 1.00;

	@ISA         = qw(Exporter);
	@EXPORT      = qw(&fail &NameToPathHash &sani &quit);
	%EXPORT_TAGS = (  );     # eg: TAG => [ qw!name1 name2! ],

	# your exported package globals go here,
	# as well as any optionally exported functions
	@EXPORT_OK   = qw();
}

use vars      @EXPORT_OK;
use Debbugs::Config qw(%Globals);
use FileHandle;
my @cleanups;
my $DEBUG = new FileHandle;

sub fail
{
	print "$_[0]\n";
	exit 1;
}
sub NameToPathHash
{
#   12345 -> 5/4/3/12345
#   12 -> s/2/1/12
    my $name = $_[0];
    my $tmp = $name;
    $name =~ /^.*?(.)(.)(.)$/ ;
    if(!defined($1)) {
	$name =~ /^(.*?)(.)(.)$/ ;
	$tmp = "$1$2$3"."s";
    }
    $tmp =~ /^.*?(.)(.)(.)$/ ;
    return "$3/$2/$1/$name";
}

sub DEBUG
{
    print $DEBUG $_;
}
sub quit
{
    DEBUG("quitting >$_[0]<\n");
    my $u;
    while ($u= $cleanups[$#cleanups]) { &$u; }
    die "*** $_[0]\n";
}
sub sani
{
    HTML::Entities::encode($a);
}
1;
END { }       # module clean-up code here (global destructor)
