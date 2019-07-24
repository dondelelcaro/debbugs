# This module is part of debbugs, and is released
# under the terms of the GPL version 2, or any later version. See the
# file README and COPYING for more information.
# Copyright 2017 by Don Armstrong <don@donarmstrong.com>.
use utf8;
package Debbugs::DB::ResultSet::Suite;

=head1 NAME

Debbugs::DB::ResultSet::Suite - Suite table actions

=head1 SYNOPSIS



=head1 DESCRIPTION



=cut

use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

sub get_suite_id {
    my ($self,$suite) = @_;
    if (ref($suite)) {
	if (ref($suite) eq 'HASH') {
	    $suite = $suite->{id}
	} else {
	    $suite = $suite->id();
	}
    }
    else {
	if ($suite !~ /^\d+$/) {
	    $suite = $self->result_source->schema->
		resultset('Suite')->
		search_rs({codename => $suite},
			 {result_class => 'DBIx::Class::ResultClass::HashRefInflator',
			 })->first();
	    if (defined $suite) {
		$suite = $suite->{id};
	    }
	}
    }
    return $suite;
}

1;

__END__
