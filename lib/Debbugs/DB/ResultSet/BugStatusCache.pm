# This module is part of debbugs, and is released
# under the terms of the GPL version 2, or any later version. See the
# file README and COPYING for more information.
# Copyright 2017 by Don Armstrong <don@donarmstrong.com>.
use utf8;
package Debbugs::DB::ResultSet::BugStatusCache;

=head1 NAME

Debbugs::DB::ResultSet::BugStatusCache - Bug result set operations

=head1 SYNOPSIS



=head1 DESCRIPTION



=cut

use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

use List::AllUtils qw(natatime);


=over

=item update_bug_status

	$s->resultset('BugStatusCache')->
	    update_bug_status($bug->id,
			      $suite->{id},
			      undef,
			      $presence,
			      );

Update the status information for a particular bug at a particular suite

=cut

sub update_bug_status {
    my ($self,$bug,$suite,$arch,$status,$modified,$asof) = @_;
    return $self->result_source->schema->
	select_one(<<'SQL',$bug,$suite,$arch,$status,$status);
INSERT INTO bug_status_cache AS bsc
(bug,suite,arch,status,modified,asof)
VALUES (?,?,?,?,NOW(),NOW())
ON CONFLICT (bug,COALESCE(suite,0),COALESCE(arch,0)) DO
UPDATE
 SET asof=NOW(),modified=CASE WHEN bsc.status=? THEN bsc.modified ELSE NOW() END
RETURNING status;
SQL
}


=back

=cut


1;

__END__
