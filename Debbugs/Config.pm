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
    @EXPORT_OK   = qw(%Globals %Severities &ParseConfigFile);
}

use vars      @EXPORT_OK;

# initialize package globals, first exported ones
%Severities = ();
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
		"work-dir" => "/var/lib/debbugs/spool",
		"spool-dir" => "/var/lib/debbugs/spool/incoming",
		"www-dir" => "/var/lib/debbugs/www",
		"doc-dir" => "/var/lib/debbugs/www/txt",
		"maintainer-file" => "/etc/debbugs/Maintainers" );

sub strip
{   my $string = $_[0];
    chop $string while $string =~ /\s$/; 
    return $string;
}

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

	if ( /^Email Domain\s*[:=]\s*([^#]*)/i )
	{ $Globals{ 'email-domain' } = strip( $1 ); }
	elsif ( /^List Domain\s*[:=]\s*([^#]*)/i )
	{ $Globals{ 'list-domain' } = strip( $1 ); }
	elsif ( /^Web Domain\s*[:=]\s*([^#]*)/i )
	{ $Globals{ 'web-domain' } = strip( $1 ); }
	elsif ( /^CGI Domain\s*[:=]\s*([^#]*)/i )
	{ $Globals{ 'cgi-domain' } = strip( $1 ); }
	elsif ( /^Short Name\s*[:=]\s*([^#]*)/i )
	{ $Globals{ 'project-short' } = strip( $1 ); }
	elsif ( /^Long Name\s*[:=]\s*([^#]*)/i )
	{ $Globals{ 'project-long' } = strip( $1 ); }
	elsif ( /^Owner Name\s*[:=]\s*([^#]*)/i )
	{ $Globals{ 'owner-name' } = strip( $1 ); }
	elsif ( /^Owner Email\s*[:=]\s*([^#]*)/i )
	{ $Globals{ 'owner-email' } = strip( $1 ); }
	elsif ( /^Spool Dir\s*[:=]\s*([^#]*)/i )
	{ $Globals{ 'spool-dir' } = strip( $1 ); }
	elsif ( /^Work Dir\s*[:=]\s*([^#]*)/i )
	{ $Globals{ 'work-dir' } = strip( $1 ); }
	elsif ( /^Web Dir\s*[:=]\s*([^#]*)/i )
	{ $Globals{ 'www-dir' } = strip( $1 ); }
	elsif ( /^Doc Dir\s*[:=]\s*([^#]*)/i )
	{ $Globals{ 'doc-dir' } = strip( $1 ); }
	elsif ( /^Maintainer File\s*[:=]\s*([^#]*)/i )
	{ $Globals{ 'maintainer-file' } = strip( $1 ); }
	elsif ( /^Submit List\s*[:=]\s*([^#]*)/i )
	{ $Globals{ 'submit-list' } = strip( $1 ); }
	elsif ( /^Maint List\s*[:=]\s*([^#]*)/i )
	{ $Globals{ 'maint-list' } = strip( $1 ); }
	elsif ( /^Quiet List\s*[:=]\s*([^#]*)/i )
	{ $Globals{ 'quiet-list' } = strip( $1 ); }
	elsif ( /^Forwarded List\s*[:=]\s*([^#]*)/i )
	{ $Globals{ 'forwarded-list' } = strip( $1 ); }
	elsif ( /^Done List\s*[:=]\s*([^#]*)/i )
	{ $Globals{ 'done-list' } = strip( $1 ); }
	elsif ( /^Request List\s*[:=]\s*([^#]*)/i )
	{ $Globals{ 'request-list' } = strip( $1 ); }
	elsif ( /^Submitter List\s*[:=]\s*([^#]*)/i )
	{ $Globals{ 'submitter-list' } = strip( $1 ); }
	elsif ( /^Control List\s*[:=]\s*([^#]*)/i )
	{ $Globals{ 'control-list' } = strip( $1 ); }
	elsif ( /^Summary List\s*[:=]\s*([^#]*)/i )
	{ $Globals{ 'summary-list' } = strip( $1 ); }
	elsif ( /^Mirror List\s*[:=]\s*([^#]*)/i )
	{ $Globals{ 'mirror-list' } = strip( $1 ); }
	elsif ( /^Mailer\s*[:=]\s*([^#]*)/i )
	{ $Globals{ 'mailer' } = strip( $1 ); }
	elsif ( /^Singular Term\s*[:=]\s*([^#]*)/i )
	{ $Globals{ 'singular' } = strip( $1 ); }
	elsif ( /^Plural Term\s*[:=]\s*([^#]*)/i )
	{ $Globals{ 'plural' } = strip( $1 ); }
	elsif ( /^Expire Age\s*[:=]\s*([^#]*)/i )
	{ $Globals{ 'expire-age' } = strip( $1 ); }
	elsif ( /^Save Expired Bugs\s*[:=]\s*([^#]*)/i )
	{ $Globals{ 'save-expired' } = strip( $1 ); }
	elsif ( /^Mirrors\s*[:=]\s*([^#]*)/i )
	{ $Globals{ 'mirrors' } = strip( $1 ); }
	elsif ( /^Default Severity\s*[:=]\s*([^#]*)/i )
	{ $Globals{ 'default-severity' } = strip( $1 ); }
	elsif ( /^Normal Severity\s*[:=]\s*([^#]*)/i )
	{ $Globals{ 'normal-severity' } = strip( $1 ); }
        elsif ( /^Severity\s+#*(\d+)\s*[:=]\s*([^#]*)/i )
        {   $Severity{ $1 } = $2;
            print "D2: (config) Severity $1=$choice{$1}\n" if $Globals{ 'debug' } > 1;
        }
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
