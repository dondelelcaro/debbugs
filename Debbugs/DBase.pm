# TODO: Implement 'stale' checks, so that there is no need to explicitly
#	write out a record, before closing.

package Debbugs::DBase;  # assumes Some/Module.pm

use strict;

BEGIN {
	use Exporter   ();
	use vars       qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

	# set the version for version checking
	$VERSION     = 1.00;

	@ISA         = qw(Exporter);
	@EXPORT      = qw( %Record %BTags);
	%EXPORT_TAGS = ( );     # eg: TAG => [ qw!name1 name2! ],

	# your exported package globals go here,
	# as well as any optionally exported functions
	@EXPORT_OK   = qw( %Record %BTags);
}

use vars      @EXPORT_OK;
use Fcntl ':flock';
use Debbugs::Config;
use Debbugs::Email;
use Debbugs::Common;
use Debbugs::DBase::Log;
use Debbugs::DBase::Log::Html;
use Debbugs::DBase::Log::Message;
use Debbugs::DBase::Log::Mail;

use FileHandle;
use File::Basename qw(&dirname);
use File::Path;

%Record = ();
%BTags= ( );

my $LoadedRecord = 0;
my $OpenedRecord = 0;
my $OpenedLog = 0;
my $FileLocked = 0;
my $FileHandle = new FileHandle;
my $LogfileHandle = new FileHandle;

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
	$BTags{ "BUG_$tag" } = $line;
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
    print "V: Reading status $record\n" if $Globals{ 'verbose' };
    if ( $record ne $LoadedRecord )
    {
	my @data;

	seek( $FileHandle, 0, 0 );
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
    print "V: Writing status $LoadedRecord\n" if $Globals{ 'verbose' };
    seek( $FileHandle, 0, 0 );
    for( my $i = 0; $i < $#fields; $i++ )
    {
	if ( defined( $fields[$i] ) )
	{ print $FileHandle $Record{ $fields[$i] } . "\n"; }
	else { print $FileHandle "\n"; }
    }
}

sub GetFileName
{
    my ($prePaths, $stub, $postPath, $desc, $new) = (shift, shift, shift, shift, shift);
    my $path;
    foreach my $prePath (@$prePaths) {
	$path = "/" . $prePath . "/" . $stub . $postPath;
	print "V: Opening $desc $stub\n" if $Globals{ 'verbose' };
	print "D2: (DBase) trying $path\n" if $Globals{ 'debug' } > 1;
	if( ! -r $Globals{ "work-dir" } . $path ) {
	    $path = "/" . $prePath . "/" . &NameToPathHash($stub) . $postPath;
	    print "D2: (DBase) trying $path\n" if $Globals{ 'debug' } > 1;
	    if( ! -r $Globals{ "work-dir" } . $path ) {
		next if( !$new =~ "new" );
	    }
	}
	if( -r $Globals{ "work-dir" } . $path ) {
	    return $path;
	}
	if( ( ! -r $Globals{ "work-dir" } . $path ) && defined($new) && $new =~ "new") {
	    my $dir = dirname( $path );
	    if ( ! -d $Globals{ "work-dir" } . $dir ) {
		mkpath($Globals{ "work-dir" } . $dir);
	    }
	    return $path;
	}
    }
    return undef;
}
sub OpenFile
{
    my ($prePaths, $stub, $postPath, $desc, $new) = (shift, shift, shift, shift, shift);
    my $fileName = GetFileName($prePaths, $stub, $postPath, $desc, $new);
    my $handle = new FileHandle;
    open( $handle, $Globals{ "work-dir" } . $fileName ) && return $handle;
    return undef;
}

sub OpenRecord
{
    my $record = $_[0];
    if ( $record ne $OpenedRecord )
    {
	$FileHandle = OpenFile ["db", "archive"], $record, ".status", "status", $_[1];
	flock( $FileHandle, LOCK_EX ) || &fail( "Unable to lock record $record\n" );
	$OpenedRecord = $record;
    }
}

sub CloseRecord
{
    print "V: Closing status $LoadedRecord\n" if $Globals{ 'verbose' };
    close $FileHandle;
    $OpenedRecord = 0;
}

sub OpenLogfile
{
    my $record = $_[0];
    if ( $record ne $OpenedLog )
    {
	$LogfileHandle = OpenFile(["db", "archive"], $record, ".log", "log");
	$OpenedLog = $record;
    }
}

sub ReadLogfile
{
    my $record = $_[0];
    if ( $record eq $OpenedLog )
    {
	seek( $LogfileHandle, 0, 0 );
	my $log = new Debbugs::DBase::Log;
	$log->Load($LogfileHandle);
    }
}

sub CloseLogfile
{
    print "V: Closing log $OpenedLog\n" if $Globals{ 'verbose' };
    close $LogfileHandle;
    $OpenedLog = 0;
}
sub GetBugList
{
# TODO: This is ugly, but the easiest for me to implement.
#	If you have a better way, then please send a patch.
#
    my $dir = new FileHandle;

    my $prefix;
    my $paths = shift;
    my @paths;
    if ( !defined($paths) ) {
	@paths = ("db");
    } else {
	@paths = @$paths;
    }
    my @ret;
    my $path;
    foreach $path (@paths) {
	$prefix = $Globals{ "work-dir" } . "/" . $path . "/";
	opendir $dir, $prefix;
	my @files = readdir($dir);
	closedir $dir;
	foreach (grep { /\d*\d\d.status/ } @files) {
	    next if ( ! -s $prefix . "/" . $_ );
	    s/.status$//;
	    push @ret, $_;
#	    print "$_ -> $_\n";
	}
	foreach (grep { /^[s0-9]$/ } @files) {
	    my $_1 = $_;
	    opendir $dir, $prefix . $_1;
	    my @files = grep { /^\d$/ } readdir($dir);
	    closedir $dir;
	    foreach (@files) {
		my $_2 = $_;
		opendir $dir, "$prefix$_1/$_2";
		my @files = grep { /^\d$/ } readdir($dir);
		close $dir;
		foreach (@files) {
		    my $_3 = $_;
		    opendir $dir, "$prefix$_1/$_2/$_3";
		    my @files = grep { /\d*\d\d.status/ } readdir($dir);
		    close $dir;
		    foreach (@files) {
			next if ( ! -s "$prefix$_1/$_2/$_3/$_" );
			s/.status$//;
			push @ret, $_;
#			print "$_ -> $_1/$_2/$_3/$_\n";
		    }
		}
	    }
	}
    }
    return @ret;
}

1;

END { }       # module clean-up code here (global destructor)
