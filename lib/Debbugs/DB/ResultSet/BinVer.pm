# This module is part of debbugs, and is released
# under the terms of the GPL version 2, or any later version. See the
# file README and COPYING for more information.
# Copyright 2017 by Don Armstrong <don@donarmstrong.com>.
use utf8;
package Debbugs::DB::ResultSet::BinVer;

=head1 NAME

Debbugs::DB::ResultSet::BinVer - Source Version association

=head1 SYNOPSIS



=head1 DESCRIPTION



=cut

use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

use Debbugs::DB::Util qw(select_one);


sub get_bin_ver_id {
    my ($self,$bin_pkg_id,$bin_ver,$arch_id,$src_ver_id) = @_;
    return $self->result_source->schema->storage->
	dbh_do(sub {
		   my ($s,$dbh,$bp_id,$bv,$a_id,$sv_id) = @_;
		   return select_one($dbh,<<'SQL',
WITH ins AS (
INSERT INTO bin_ver (bin_pkg,src_ver,arch,ver)
VALUES (?,?,?,?) ON CONFLICT (bin_pkg,arch,ver) DO NOTHING RETURNING id
)
SELECT id FROM ins
UNION ALL
SELECT id FROM bin_ver WHERE bin_pkg = ? AND arch = ? AND ver = ?
LIMIT 1;
SQL
				     $bp_id,$sv_id,
				     $a_id,$bv,
				     $bp_id,$a_id,
				     $bv);
	       },
	       $bin_pkg_id,$bin_ver,$arch_id,$src_ver_id
	      );
}

1;

__END__
