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

use Debbugs::DB::Util qw(select_one);


sub insert_suite_bin_ver_association {
    my ($self,$suite_id,$bin_ver_id) = @_;
    return $self->result_source->schema->storage->
	dbh_do(sub {
		   my ($s,$dbh,$s_id,$bv_id) = @_;
		   return select_one($dbh,<<'SQL',$s_id,$bv_id);
INSERT INTO bin_associations (suite,bin)
   VALUES (?,?) ON CONFLICT (suite,bin) DO
    UPDATE SET modified = NOW()
   RETURNING id;
SQL
	       },
	       $suite_id,$bin_ver_id
	      );
}

1;

__END__
