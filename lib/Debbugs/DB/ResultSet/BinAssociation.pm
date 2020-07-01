# This module is part of debbugs, and is released
# under the terms of the GPL version 2, or any later version. See the
# file README and COPYING for more information.
# Copyright 2017 by Don Armstrong <don@donarmstrong.com>.
use utf8;
package Debbugs::DB::ResultSet::BinAssociation;

=head1 NAME

Debbugs::DB::ResultSet::BinAssociation - Binary/Suite Associations

=head1 SYNOPSIS



=head1 DESCRIPTION



=cut

use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

sub insert_suite_bin_ver_association {
    my ($self,$suite_id,$bin_ver_id) = @_;
    return $self->result_source->schema->
	select_one(<<'SQL',$suite_id,$bin_ver_id);
INSERT INTO bin_associations (suite,bin)
   VALUES (?,?) ON CONFLICT (suite,bin) DO
    UPDATE SET modified = NOW()
   RETURNING id;
SQL
}

1;

__END__
