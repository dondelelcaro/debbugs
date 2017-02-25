# This module is part of debbugs, and is released
# under the terms of the GPL version 2, or any later version. See the
# file README and COPYING for more information.
# Copyright 2017 by Don Armstrong <don@donarmstrong.com>.
use utf8;
package Debbugs::DB::ResultSet::SrcPkg;

=head1 NAME

Debbugs::DB::ResultSet::SrcPkg - Source Package

=head1 SYNOPSIS



=head1 DESCRIPTION



=cut

use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

use Debbugs::DB::Util qw(select_one);

sub src_pkg_and_ver_in_suite {
    my ($self,$suite) = @_;
    if (ref($suite)) {
	if (ref($suite) eq 'HASH') {
	    $suite = $suite->{id}
	} else {
	   $suite = $suite->id();
	}
    } else {
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
    return
	$self->search_rs({'src_associations.suite' => $suite,
			 },
			{join => {src_vers => 'src_associations'},
			 result_class => 'DBIx::Class::ResultClass::HashRefInflator',
			 columns => [qw(me.pkg src_vers.ver src_associations.id)]
			},
			)->all;
}


sub get_src_pkg_id {
    my ($self,$source) = @_;
    return $self->result_source->schema->storage->
	dbh_do(sub {
		   my ($s,$dbh,$source) = @_;
		   return select_one($dbh,<<'SQL',$source,$source);
WITH ins AS (
INSERT INTO src_pkg (pkg)
   VALUES (?) ON CONFLICT (pkg,disabled) DO NOTHING RETURNING id
)
SELECT id FROM ins
UNION ALL
SELECT id FROM src_pkg where pkg = ? AND disabled = 'infinity'::timestamptz
LIMIT 1;
SQL
	       },
	       $source
	      );
}

1;

__END__
