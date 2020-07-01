# This module is part of debbugs, and is released
# under the terms of the GPL version 2, or any later version. See the
# file README and COPYING for more information.
# Copyright 2017 by Don Armstrong <don@donarmstrong.com>.
use utf8;
package Debbugs::DB::ResultSet::Bug;

=head1 NAME

Debbugs::DB::ResultSet::Bug - Bug result set operations

=head1 SYNOPSIS



=head1 DESCRIPTION



=cut

use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

use List::AllUtils qw(natatime);


=over

=item quick_insert_bugs

     $s->result_set('Bug')->quick_insert_bugs(@bugs);

Quickly insert a set of bugs (without any useful information, like subject,
etc). This should probably only be called when inserting bugs in the database
for first time.

=cut


sub quick_insert_bugs {
    my ($self,@bugs) = @_;

    my $it = natatime 2000, @bugs;

    while (my @b = $it->()) {
	$self->result_source->schema->
	    txn_do(sub{
		       for my $b (@b) {
			   $self->quick_insert_bug($b);
		       }
		   });
    }
}

=item quick_insert_bug

     $s->result_set('Bug')->quick_insert_bug($bug);

Quickly insert a single bug (called by quick_insert_bugs). You should probably
actually be calling C<Debbugs::DB::Load::load_bug> instead of this function.

=cut

sub quick_insert_bug {
    my ($self,$bug) = @_;
    return $self->result_source->schema->
	select_one(<<'SQL',$bug);
INSERT INTO bug (id,subject,severity) VALUES (?,'',1)
ON CONFLICT (id) DO NOTHING RETURNING id;
SQL
}


=back

=cut


1;

__END__
