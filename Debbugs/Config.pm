package Debbugs::Config;  # assumes Some/Module.pm

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
    @EXPORT_OK   = qw(%Globals %Severity &ParseConfigFile);
}

use vars      @EXPORT_OK;
use Debbugs::Common;

# initialize package globals, first exported ones
%Severity = ();
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
		"owner-email" => "owner\@bugs.domain.com",
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
    open(CONFIG,$configfile) or &fail( "E: Unable to open `$configfile'" );
    @config = <CONFIG>;
    close CONFIG;

    #parse config file
    print "V: Parsing Config File\n" if $Globals{ "verbose" };
    print "D3: Parse Config:\n@config\n" if $Globals{ 'debug' } > 2;
    print "D1: Configuration\n" if $Globals{ 'debug' };

    for( my $i=0; $i<=$#config; $i++)
    {	$_ = $config[$i];
	chop $_;
	next unless length $_;
	next if /^#/;

	if ( /^Email Domain\s*[:=]\s*([^#]*)/i )
	{   $Globals{ 'email-domain' } = strip( $1 ); 
	    $GTags{ 'EMAIL_DOMAIN' } = $Globals{ 'email-domain' };
	    print "\tEmail Domain = $Globals{ 'email-domain' }\n" if $Globals{ 'debug' };
	}
	elsif ( /^List Domain\s*[:=]\s*([^#]*)/i )
	{   $Globals{ 'list-domain' } = strip( $1 ); 
	    $GTags{ 'LIST_DOMAIN' } = $Globals{ 'list-domain' };
	    print "\tList Domain = $Globals{ 'list-domain' }\n" if $Globals{ 'debug' };
	}
	elsif ( /^Web Domain\s*[:=]\s*([^#]*)/i )
	{   $Globals{ 'web-domain' } = strip( $1 ); 
	    $GTags{ 'WEB_DOMAIN' } = $Globals{ 'web-domain' };
	    print "\tWeb Domain = $Globals{ 'web-domain' }\n" if $Globals{ 'debug' };
	}
	elsif ( /^CGI Domain\s*[:=]\s*([^#]*)/i )
	{   $Globals{ 'cgi-domain' } = strip( $1 ); 
	    $GTags{ 'CGI_DOMAIN' } = $Globals{ 'cgi-domain' };
	    print "\tCGI Domain = $Globals{ 'cgi-domain' }\n" if $Globals{ 'debug' };
	}
	elsif ( /^Short Name\s*[:=]\s*([^#]*)/i )
	{   $Globals{ 'project-short' } = strip( $1 ); 
	    $GTags{ 'SHORT_NAME' } = $Globals{ 'project-short' };
	    print "\tShort Name = $Globals{ 'project-short' }\n" if $Globals{ 'debug' };
	}
	elsif ( /^Long Name\s*[:=]\s*([^#]*)/i )
	{   $Globals{ 'project-long' } = strip( $1 ); 
	    $GTags{ 'LONG_NAME' } = $Globals{ 'project-long' };
	    print "\tLong Name = $Globals{ 'project-long' }\n" if $Globals{ 'debug' };
	}
	elsif ( /^Owner Name\s*[:=]\s*([^#]*)/i )
	{   $Globals{ 'owner-name' } = strip( $1 ); 
	    $GTags{ 'OWNER_NAME' } = $Globals{ 'owner-name' };
	    print "\tOwner Name = $Globals{ 'owner-name' }\n" if $Globals{ 'debug' };
	}
	elsif ( /^Owner Email\s*[:=]\s*([^#]*)/i )
	{   $Globals{ 'owner-email' } = strip( $1 ); 
	    $GTags{ 'OWNER_EMAIL' } = $Globals{ 'owner-email' };
	    print "\tOWNER Email = $Globals{ 'owner-email' }\n" if $Globals{ 'debug' };
	}
	elsif ( /^Spool Dir\s*[:=]\s*([^#]*)/i )
	{   $Globals{ 'spool-dir' } = strip( $1 ); 
	    print "\tSpool Dir = $Globals{ 'spool-dir' }\n" if $Globals{ 'debug' };
	}
	elsif ( /^Work Dir\s*[:=]\s*([^#]*)/i )
	{   $Globals{ 'work-dir' } = strip( $1 ); 
	    print "\tWork Dir = $Globals{ 'work-dir' }\n" if $Globals{ 'debug' };
	}
	elsif ( /^Web Dir\s*[:=]\s*([^#]*)/i )
	{   $Globals{ 'www-dir' } = strip( $1 ); 
	    print "\tWeb Dir = $Globals{ 'www-dir' }\n" if $Globals{ 'debug' };
	}
	elsif ( /^Doc Dir\s*[:=]\s*([^#]*)/i )
	{   $Globals{ 'doc-dir' } = strip( $1 ); 
	    print "\tDoc Dir = $Globals{ 'doc-dir' }\n" if $Globals{ 'debug' };
	}
	elsif ( /^Maintainer File\s*[:=]\s*([^#]*)/i )
	{   $Globals{ 'maintainer-file' } = strip( $1 ); 
	    print "\tMaintainer File = $Globals{ 'maintainer-file' }\n" if $Globals{ 'debug' };
	}
	elsif ( /^Submit List\s*[:=]\s*([^#]*)/i )
	{   $Globals{ 'submit-list' } = strip( $1 ); 
	    $GTags{ 'SUBMIT_LIST' } = $Globals{ 'submit-list' };
	    print "\tSubmit List = $Globals{ 'submit-list' }\n" if $Globals{ 'debug' };
	}
	elsif ( /^Maint List\s*[:=]\s*([^#]*)/i )
	{   $Globals{ 'maint-list' } = strip( $1 ); 
	    $GTags{ 'MAINT_LIST' } = $Globals{ 'maint-list' };
	    print "\tMaint List = $Globals{ 'maint-list' }\n" if $Globals{ 'debug' };
	}
	elsif ( /^Quiet List\s*[:=]\s*([^#]*)/i )
	{   $Globals{ 'quiet-list' } = strip( $1 ); 
	    $GTags{ 'QUIET_LIST' } = $Globals{ 'quiet-list' };
	    print "\tQuiet List = $Globals{ 'quiet-list' }\n" if $Globals{ 'debug' };
	}
	elsif ( /^Forwarded List\s*[:=]\s*([^#]*)/i )
	{   $Globals{ 'forwarded-list' } = strip( $1 ); 
	    $GTags{ 'FORWARDED_LIST' } = $Globals{ 'forwarded-list' };
	    print "\tForwarded List = $Globals{ 'forwarded-list' }\n" if $Globals{ 'debug' };
	}
	elsif ( /^Done List\s*[:=]\s*([^#]*)/i )
	{   $Globals{ 'done-list' } = strip( $1 ); 
	    $GTags{ 'DONE_LIST' } = $Globals{ 'done-list' };
	    print "\tDone List = $Globals{ 'done-list' }\n" if $Globals{ 'debug' };
	}
	elsif ( /^Request List\s*[:=]\s*([^#]*)/i )
	{   $Globals{ 'request-list' } = strip( $1 ); 
	    $GTags{ 'REQUEST_LIST' } = $Globals{ 'request-list' };
	    print "\tRequest List = $Globals{ 'request-list' }\n" if $Globals{ 'debug' };
	}
	elsif ( /^Submitter List\s*[:=]\s*([^#]*)/i )
	{   $Globals{ 'submitter-list' } = strip( $1 ); 
	    $GTags{ 'SUBMITTER_LIST' } = $Globals{ 'submitter-list' };
	    print "\tSubmitter List = $Globals{ 'submitter-list' }\n" if $Globals{ 'debug' };
	}
	elsif ( /^Control List\s*[:=]\s*([^#]*)/i )
	{   $Globals{ 'control-list' } = strip( $1 ); 
	    $GTags{ 'CONTROL_LIST' } = $Globals{ 'control-list' };
	    print "\tControl List = $Globals{ 'control-list' }\n" if $Globals{ 'debug' };
	    $GTags{ '' } = $Globals{ '' };
	    print "\t = $Globals{ '' }\n" if $Globals{ 'debug' };
	}
	elsif ( /^Summary List\s*[:=]\s*([^#]*)/i )
	{   $Globals{ 'summary-list' } = strip( $1 ); 
	}
	elsif ( /^Mirror List\s*[:=]\s*([^#]*)/i )
	{   $Globals{ 'mirror-list' } = strip( $1 ); 
	}
	elsif ( /^Mailer\s*[:=]\s*([^#]*)/i )
	{   $Globals{ 'mailer' } = strip( $1 ); 
	}
	elsif ( /^Singular Term\s*[:=]\s*([^#]*)/i )
	{   $Globals{ 'singular' } = strip( $1 ); 
	}
	elsif ( /^Plural Term\s*[:=]\s*([^#]*)/i )
	{   $Globals{ 'plural' } = strip( $1 ); 
	}
	elsif ( /^Expire Age\s*[:=]\s*([^#]*)/i )
	{   $Globals{ 'expire-age' } = strip( $1 ); 
	}
	elsif ( /^Save Expired Bugs\s*[:=]\s*([^#]*)/i )
	{   $Globals{ 'save-expired' } = strip( $1 ); 
	}
	elsif ( /^Mirrors\s*[:=]\s*([^#]*)/i )
	{   $Globals{ 'mirrors' } = strip( $1 ); 
	}
	elsif ( /^Default Severity\s*[:=]\s*([^#]*)/i )
	{   $Globals{ 'default-severity' } = strip( $1 ); 
	}
	elsif ( /^Normal Severity\s*[:=]\s*([^#]*)/i )
	{   $Globals{ 'normal-severity' } = strip( $1 ); 
	}
        elsif ( /^Severity\s+#*(\d+)\s*[:=]\s*([^#]*)/i )
        {   $Severity{ $1 } = $2;
            print "D2: (config) Severity $1=$Severity{$1}\n" if $Globals{ 'debug' } > 1;
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
