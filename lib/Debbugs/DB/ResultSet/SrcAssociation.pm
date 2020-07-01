# This module is part of debbugs, and is released
# under the terms of the GPL version 2, or any later version. See the
# file README and COPYING for more information.
# Copyright 2017 by Don Armstrong <don@donarmstrong.com>.
use utf8;
package Debbugs::DB::ResultSet::SrcAssociation;

=head1 NAME

Debbugs::DB::ResultSet::SrcAssociation - Source/Suite Associations

=head1 SYNOPSIS



=head1 DESCRIPTION



=cut

use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

sub insert_suite_src_ver_association {
    my ($self,$suite_id,$src_ver_id) = @_;
    return $self->result_source->schema->
	select_one(<<'SQL',$suite_id,$src_ver_id);
INSERT INTO src_associations (suite,source)
   VALUES (?,?) ON CONFLICT (suite,source) DO
     UPDATE SET modified = NOW()
RETURNING id;
SQL
}

1;

__END__
