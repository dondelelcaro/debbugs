package Debbugs::DBase;  # assumes Some/Module.pm

use strict;

BEGIN {
	use Exporter   ();
	use vars       qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

	# set the version for version checking
	$VERSION     = 1.00;

	@ISA         = qw(Exporter);
	@EXPORT      = qw( %Record );
	%EXPORT_TAGS = ( );     # eg: TAG => [ qw!name1 name2! ],

	# your exported package globals go here,
	# as well as any optionally exported functions
	@EXPORT_OK   = qw( %Record );
}

use vars      @EXPORT_OK;
use Fcntl ':flock';
use Debbugs::Config;
use Debbugs::Email;
use Debbugs::Common;
use FileHandle;

%Record = ();

my $LoadedRecord = 0;
my $FileLocked = 0;
my $FileHandle = new FileHandle;

sub ParseVersion1Record
{
    my @data = @_;
    my @fields = ( "originator", "date", "subject", "msgid", "package",
		"keywords", "done", "forwarded", "mergedwith", "severity" );
    my $i = 0;
    my $tag;

    print "D2: (DBase) Record Fields:\n" if $Globals{ 'debug' } > 1;
    foreach my $line ( @data )
    {
	chop( $line );
	$tag = $fields[$i];
	$Record{ $tag } = $line;
    	print "\t $tag = $line\n" if $Globals{ 'debug' } > 1;
	$i++;
	$GTags{ "BUG_$tag" } = $line;
    }
}

sub ParseVersion2Record
{
    # I envision the next round of records being totally different in
    # meaning.  In order to maintain compatability, version tagging will be
    # implemented in thenext go around and different versions will be sent
    # off to different functions to be parsed and interpreted into a format
    # that the rest of the system will understand.  All data will be saved
    # in whatever 'new" format ixists.  The difference will be a "Version: x"
    # at the top of the file.

    print "No version 2 records are understood at this time\n";
    exit 1;
}

sub ReadRecord
{
    my $record = $_[0];
    print "V: Reading $record\n" if $Globals{ 'verbose' };
    if ( $record ne $LoadedRecord )
    {
	my $path = '';
	my @data;

        print "D1: (DBase) $record is being loaded\n" if $Globals{ 'debug' }; 
	
	#find proper directory to store in
        #later, this will be for tree'd data directory the way
        #expire is now,..
	$path = "/db/".$record.".status";
	print "D2: (DBase) $path found as data path\n" if $Globals{ 'debug' } > 1;
    
	open( $FileHandle, $Globals{ "work-dir" } . $path ) 
	    || &fail( "Unable to open record: ".$Globals{ "work-dir" }."$path\n");
	flock( $FileHandle, LOCK_EX ) || &fail( "Unable to lock record $record\n" );
	@data = <$FileHandle>;
	if ( scalar( @data ) =~ /Version: (\d*)/ )
	{
	    if ( $1 == 2 )
	    { &ParseVersion2Record( @data ); }
	    else
	    { &fail( "Unknown record version: $1\n"); }
	}
	else { &ParseVersion1Record( @data ); }
	$LoadedRecord = $record;
    }
    else { print "D1: (DBase) $record is already loaded\n" if $Globals{ 'debug' }; }

}

sub WriteRecord
{
    my @fields = ( "originator", "date", "subject", "msgid", "package",
		"keywords", "done", "forwarded", "mergedwith", "severity" );
    seek( $FileHandle, 0, 0 );
    for( my $i = 0; $i < $#fields; $i++ )
    {
	if ( defined( $fields[$i] ) )
	{ print $FileHandle $Record{ $fields[$i] } . "\n"; }
	else { print $FileHandle "\n"; }
    }
    close $FileHandle;
    $LoadedRecord = 0;
}

1;

END { }       # module clean-up code here (global destructor)
