# This module is part of debbugs, and is released
# under the terms of the GPL version 2, or any later version. See the
# file README and COPYING for more information.
# Copyright 2017 by Don Armstrong <don@donarmstrong.com>.
use utf8;
package Debbugs::DB::ResultSet::BinPkg;

=head1 NAME

Debbugs::DB::ResultSet::BinPkg - Source Package

=head1 SYNOPSIS



=head1 DESCRIPTION



=cut

use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

use Debbugs::DB::Util qw(select_one);

sub bin_pkg_and_ver_in_suite {
    my ($self,$suite) = @_;
    $suite = $self->result_source->schema->
	resultset('Suite')->get_suite_id($suite);
    return
	$self->search_rs({'bin_associations.suite' => $suite,
			 },
			{join => {bin_vers => ['bin_associations','arch']},
			 result_class => 'DBIx::Class::ResultClass::HashRefInflator',
			 columns => [qw(me.pkg  bin_vers.ver arch.arch bin_associations.id)]
			},
			)->all;
}


sub get_bin_pkg_id {
    my ($self,$pkg) = @_;
    return $self->result_source->schema->storage->
	dbh_do(sub {
		   my ($s,$dbh,$bin_pkg) = @_;
		   return select_one($dbh,<<'SQL',$bin_pkg);
SELECT id FROM bin_pkg where pkg = ?;
SQL
	       },
	       $pkg
	      );
}
sub get_or_create_bin_pkg_id {
    my ($self,$pkg) = @_;
    return $self->result_source->schema->storage->
	dbh_do(sub {
		   my ($s,$dbh,$bin_pkg) = @_;
		   return select_one($dbh,<<'SQL',$bin_pkg,$bin_pkg);
WITH ins AS (
INSERT INTO bin_pkg (pkg)
VALUES (?) ON CONFLICT (pkg) DO NOTHING RETURNING id
)
SELECT id FROM ins
UNION ALL
SELECT id FROM bin_pkg where pkg = ?
LIMIT 1;
SQL
	       },
	       $pkg
	      );
}

1;

__END__
