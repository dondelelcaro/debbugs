# TODO: Implement 'stale' checks, so that there is no need to explicitly
#	write out a record, before closing.

package Debbugs::DBase::Log::Mail;
use Debbugs::DBase::LogEntry;
use Exporter;

use strict;
BEGIN {
	use vars	qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	@ISA = ( "Debbugs::DBase::LogEntry" );
	Debbugs::DBase::Log::Register("\2", "Mail", "Debbugs::DBase::Log::Mail");
}


sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self  = {};
    $self->{TYPE}	= "Html";
    $self->{MSG}	= shift;
    bless ($self, $class);
    return $self;
}

END { }       # module clean-up code here (global destructor)


1;
