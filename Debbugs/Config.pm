package Debvote::Config;  # assumes Some/Module.pm

use strict;

BEGIN 
{ 	use Exporter   ();
   	use vars       qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	
    # set the version for version checking
    $VERSION     = 1.00;

    @ISA         = qw(Exporter);
    @EXPORT      = qw( );
    %EXPORT_TAGS = ( );     # eg: TAG => [ qw!name1 name2! ],

    # your exported package globals go here,
    # as well as any optionally exported functions
    @EXPORT_OK   = qw(%Globals &ParseConfigFile);
}

use vars      @EXPORT_OK;

# initialize package globals, first exported ones
%Globals = (	"debug" => 0,
		"verbose" => 0,
		"quiet" => 0,
		##### domains
		"email-domain" => "bugs.domain.com",
		"list-domain" => "lists.domain.com",
		"web-domain" => "web.domain.com",
		"cgi-domain" => "cgi.domain.com",
		##### identification
		"project-short" => "debbugs",
		"project-long" => "Debbugs Test Project",
		"owner-name" => "Fred Flintstone",
		"owner-email" => "owner@bugs.domain.com",
		##### directories
		"data-dir" => "/var/lib/debbugs/spool",
		"spool-dir" => "/var/lib/debbugs/spool/incoming",
		"www-dir" => "/var/lib/debbugs/www",
		"doc-dir" => "/var/lib/debbugs/www/txt",
		"maintainer-file" => "/etc/debbugs/Maintainers",
		"database" => "debvote.db" );

#############################################################################
#  Read Config File and parse
#############################################################################
sub ParseConfigFile
{   my $configfile = $_[0];
    my @config;
    my $votetitle = '';
    my $ballottype = '';

    #load config file
    print "V: Loading Config File\n" if $Globals{ "verbose" };
    open(CONFIG,$configfile) or &::fail( "E: Unable to open `$configfile'" );
    @config = <CONFIG>;
    close CONFIG;

    #parse config file
    print "V: Parsing Config File\n" if $Globals{ "verbose" };
    print "D3: Parse Config:\n@config\n" if $Globals{ 'debug' } > 2;
    for( my $i=0; $i<=$#config; $i++)
    {	$_ = $config[$i];
	chop $_;
	next unless length $_;
	next if /^#/;
	if ( /^Ballot Type\s*[:=]\s*([^#]*)\s*(#.*)?/i )
	{   my $ballottype = $1;
	    chop $ballottype while $ballottype =~ /\s$/;
	    $ballottype =~ y/A-Z/a-z/;
	    $Globals{ 'ballottype' } = $ballottype;
	}
	elsif ( /^Database\s*[:=]\s*(\S+)/i )
	{ $Globals{ 'database' } = $1; }
	elsif( /^Ballot Ack\s*[:=]\s*([^#]*)/i )
	{ $Globals{ "response" } = $1; }
	elsif( /^Ballot Template\s*[:=]\s*([^#]*)/i )
	{ $Globals{ "ballot" } = $1; }
	elsif( /^No Ballot Letter\s*[:=]\s*([^#]*)/i )
	{ $Globals{ "noballot" } = $1; }
	elsif ( /^Title\s*[:=]\s*([^#]*)/i )
	{ $Globals{ 'title' } = $1; }
    }
    if( $Globals{ "debug" } )
    {
	print "D1: Configuration\n";
	print "\tBallot Type = $Globals{ 'ballottype' }\n";
	print "\tDatabase = $Globals{ 'database' }\n";
	print "\tBallot Ack = $Globals{ 'response' }\n";
	print "\tBallot Template = $Globals{ 'ballot' }\n";
	print "\tTitle = $Globals{ 'title' }\n";
    }
    return @config;
}

END { }       # module clean-up code here (global destructor)
