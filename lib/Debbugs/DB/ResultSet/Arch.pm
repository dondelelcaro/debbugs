# This module is part of debbugs, and is released
# under the terms of the GPL version 2, or any later version. See the
# file README and COPYING for more information.
# Copyright 2016 by Don Armstrong <don@donarmstrong.com>.
use utf8;
package Debbugs::DB::ResultSet::Arch;

=head1 NAME

Debbugs::DB::ResultSet::Arch - Architecture result set operations

=head1 SYNOPSIS



=head1 DESCRIPTION



=cut

use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

# required for hash slices
use v5.20;

sub get_archs {
    my ($self,@archs) = @_;
    my %archs;
    for my $a ($self->result_source->schema->resultset('Arch')->
	       search(undef,
		     {result_class => 'DBIx::Class::ResultClass::HashRefInflator',
		      columns => [qw[id arch]],
		     })->all()) {
	$archs{$a->{arch}} = $a->{id};
    }
    for my $a (grep {not exists $archs{$_}} @archs) {
	$archs{$a} =
	    $self->result_source->schema->resultset('Arch')->
	    find_or_create({arch => $a},
			  {columns => [qw[id arch]],
			  }
			  )->id;
    }

    return {%archs{@archs}};
}


1;

__END__
