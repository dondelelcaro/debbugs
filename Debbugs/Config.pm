package Debbugs::Config;  # assumes Some/Module.pm

use strict;

BEGIN 
{ 	use Exporter   ();
   	use vars       qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	
    # set the version for version checking
    $VERSION     = 1.00;

    @ISA         = qw(Exporter);
    @EXPORT      = qw(%Globals %Strong %Severity );
    %EXPORT_TAGS = ( );     # eg: TAG => [ qw!name1 name2! ],

    # your exported package globals go here,
    # as well as any optionally exported functions
    @EXPORT_OK   = qw(%Globals %Severity %Strong &ParseConfigFile &ParseXMLConfigFile);
}

use vars      @EXPORT_OK;
use Debbugs::Common;
use Debbugs::Email;

# initialize package globals, first exported ones
%Severity = ();
%Strong = ();
$Severity{ 'Text' } = ();
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
		##### files
		"maintainer-file" => "/etc/debbugs/Maintainers",
		"pseudo-description" => "/etc/debbugs/pseudo-packages.description");

my %ConfigMap = ( 
		"Email Domain" => "email-domain",
		"List Domain" => "list-domain",
		"Web Domain" => "web-domain",
		"CGI Domain" => "cgi-domain",
		"Short Name" => "project-short",
		"Long Name" => "project-long",
		"Owner Name" => "owner-name",
		"Owner Email" => "owner-email",
		"Owner Webpage" => "owner-webpage",
		"Spool Dir" => "spool-dir",
		"Work Dir" => "work-dir",
		"Web Dir" => "www-dir",
		"Doc Dir" => "doc-dir",
		"Maintainer File" => "maintainer-file",
		"Pseudo Description File" => "pseudo-description",
		"Submit List" => "submit-list",
		"Maint List" => "maint-list",
		"Quiet List" => "quiet-list",
		"Forwarded List" => "forwarded-list",
		"Done List" => "done-list",
		"Request List" => "request-list",
		"Submitter List" => "submitter-list",
		"Control List" => "control-list",
		"Summary List" => "summary-list",
		"Mirror List" => "mirror-list",
		"Mailer" => "mailer",
		"Singular Term" => "singluar",
		"Plural Term" => "plural",
		"Expire Age" => "expire-age",
		"Save Expired Bugs" => "save-expired",
		"Mirrors" => "mirrors",
		"Default Severity" => "default-severity",
		"Normal Severity" => "normal-severity",
	);
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

	if ( /^([^:=]*)\s*[:=]\s*([^#]*)/i ) {
	    my $key = strip( $1 );
	    my $value = strip( $2 );
	    $value = "" if(!defined($value)); 
	    if ( $key =~ /Severity\s+#*(\d+)\s*(.*)/ ) {
		my $options = $2;
		my $severity = $1;
		if( $options =~ /\btext\b/ ) {
		    $Severity{ 'Text' }{ $severity } = $value;
		    print "D2: (config) Severity $severity text = $value\n" if $Globals{ 'debug' } > 1;
		} else {
		    $Severity{ $1 } = $value;
		    print "D2: (config) Severity $severity = $value" if $Globals{ 'debug' } > 1;
		    if( $options =~ /\bdefault\b/ ) {
			$Globals{ "default-severity" } = $severity;
			print ", default" if $Globals{ 'debug' } > 1;
		    }
		    if( $options =~ /\bstrong\b/ ) {
			$Strong{ $severity } = 1;
			print ", strong" if $Globals{ 'debug' } > 1;
		    }
		    print "\n" if $Globals{ 'debug' } > 1;
		}
		next;
	    } else {
		my $map = $ConfigMap{$key};
		if(defined($map)) {
		    $Globals{ $map } = $value;
		    print "$key = '$value'\n" if $Globals{ 'debug' } > 1;
		    next;
		} else {
		    print "$key\n";
		}
	    }
	}
	print "Unknown line in config!($_)\n";
	next;
    }
    return @config;
}

END { }       # module clean-up code here (global destructor)
