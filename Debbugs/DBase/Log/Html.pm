# TODO: Implement 'stale' checks, so that there is no need to explicitly
#	write out a record, before closing.

package Debbugs::DBase::Log::Html;

use strict;

BEGIN {
	Debbugs::DBase::Log::Register("\6", "Html", "Debbugs::DBase::Log::Html");
}


sub new
{
    my $self  = {};
    $self->{TYPE}	= "Html";
    $self->{MSG}	= shift;
    bless ($self);
    return $self;
}

END { }       # module clean-up code here (global destructor)


1;
