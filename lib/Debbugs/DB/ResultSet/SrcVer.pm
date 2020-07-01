# This module is part of debbugs, and is released
# under the terms of the GPL version 2, or any later version. See the
# file README and COPYING for more information.
# Copyright 2017 by Don Armstrong <don@donarmstrong.com>.
use utf8;
package Debbugs::DB::ResultSet::SrcVer;

=head1 NAME

Debbugs::DB::ResultSet::SrcVer - Source Version association

=head1 SYNOPSIS



=head1 DESCRIPTION



=cut

use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

sub get_src_ver_id {
    my ($self,$src_pkg_id,$src_ver,$maint_id) = @_;
    return $self->result_source->schema->
	select_one(<<'SQL',
INSERT INTO src_ver (src_pkg,ver,maintainer)
   VALUES (?,?,?) ON CONFLICT (src_pkg,ver) DO
     UPDATE SET maintainer = ?
   RETURNING id;
SQL
		   $src_pkg_id,$src_ver,
		   $maint_id,$maint_id);
}

1;

__END__
