package Debbugs::Email;  

use strict;

BEGIN {
	use Exporter   ();
	use vars       qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

	# set the version for version checking
	$VERSION     = 1.00;

	@ISA         = qw(Exporter);
	@EXPORT      = qw( %GTags );
	%EXPORT_TAGS = ( );     # eg: TAG => [ qw!name1 name2! ],

	# your exported package globals go here,
	# as well as any optionally exported functions
	@EXPORT_OK   = qw( %GTags );
}

use vars @EXPORT_OK;
use Debbugs::Config qw(%Globals);

# initialize package globals, first exported ones
%GTags= ( );

#############################################################################
#  Initialize Global Tags
#############################################################################
sub InitEmailTags
{   my @config = @_;
	
    print "V: Initializing Email Tags\n" if $Globals{ 'verbose' };
    for( my $i=0; $i<=$#config; $i++)
    {	$_ = $config[$i];
	chop $_;
	next unless length $_;
	next if /^#/;
	if ( /^GTAG\s*[:=]\s*(\S)+\s*[:=]\s*([^#]*)/i )
	{   $GTags{ $1 } = $2;
	    print "D2: (email) GTag $1=$GTags{$1}\n" if $Globals{ 'debug' } > 1;
	}
    }
}

#############################################################################
#  Load File with Tags
#############################################################################
sub LoadEmail
{   my $emailfile = $_[0];
    my @email;

    open( LETTER, $emailfile ) or &::fail( "Unable to open $emailfile: $!" );
    @email = <LETTER>;
    close LETTER;
    &ProcessTags( \@email, \%GTags, "GTAG" );
    return @email;
}
#############################################################################
#  Process Tags
#############################################################################
sub ProcessTags
{   my ($email, $tagsin, $marker) = @_;
    my %tags=%$tagsin;
    my $tag;

    print "V: Processing Template Mail\n" if $Globals{ 'verbose' };
    foreach my $line ( @$email )
    {	while( $line =~ /\%$marker\_(\S*)\%/s )
	{   if( defined( $tags{ $1 } ) ) { $tag = $tags{ $1 }; }
	    else { $tag = "(missed tag $1)"; }
	    $line =~ s/\%$marker\_(\S*)\%/$tag/;
	}
    }
    1;
}

END { }       # module clean-up code here (global destructor)
1;
