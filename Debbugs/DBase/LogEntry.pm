# TODO: Implement 'stale' checks, so that there is no need to explicitly
#	write out a record, before closing.

package Debbugs::DBase::LogEntry;

use strict;
				
sub new
{
    my $self  = {};
#    $self->{LOG}    = new FileHandle;
#    $self->{AGE}    = undef;
#    $self->{PEERS}  = [];
    $self->{log}	= [];
    $self->{Load}	= &Load;
    bless ($self);
    return $self;
}
my %logClass = ();
my %logType = ();

sub Load
{
    my ($self, $handle) = (shift, shift);
    foreach (keys %$self) {
print "key=$_\n";
}
    while (<$handle>) {
	chomp;
	my ($char, $class, $type) = ($_, $logClass{ $_ }, $logType{ $_ });
	my $msg = "";
	while (<$handle>) {
	    chomp;
	    if ( $_ eq "\3" ) {
		last;
	    } else {
		$msg .= "$_\n";
	    }
	}
	if( defined($class) ) {
	    print "found handler $type for $char\n";
	    my $log = $class->new($msg);

	    my @log = $self->{log};
	    push @log, ($log);
	} else {
	    print "undefined handler for $char\n";
	}
    }
}

BEGIN {
        use Exporter   ();
        use vars       qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

        # set the version for version checking
        $VERSION     = 1.00;

        @ISA         = qw(Exporter);
        @EXPORT      = qw(new);
        %EXPORT_TAGS = ( );     # eg: TAG => [ qw!name1 name2! ],

        # your exported package globals go here,
        # as well as any optionally exported functions
        @EXPORT_OK   = qw();

}

1;
