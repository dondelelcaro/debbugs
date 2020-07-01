# This module is part of debbugs, and is released
# under the terms of the GPL version 2, or any later version. See the
# file README and COPYING for more information.
# Copyright 2017 by Don Armstrong <don@donarmstrong.com>.

package Debbugs::DB::Util;

=head1 NAME

Debbugs::DB::Util -- Utility routines for the database

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 BUGS

None known.

=cut

use warnings;
use strict;

use base qw(DBIx::Class);

use Debbugs::Common qw(open_compressed_file);

=head2 select

Routines for select requests

=over

=item select_one

	$schema->select_one($sql,@bind_vals)

Returns the first column from the first row returned from a select statement

=cut

sub select_one {
    my ($self,$sql,@bind_vals) = @_;
    my $results =
	$self->storage->
	dbh_do(sub {
		   my ($s,$dbh) = @_;
		   my $sth = $dbh->
        prepare_cached($sql,
                      {dbi_dummy => __FILE__.__LINE__ })
        or die "Unable to prepare statement: $sql";
		   $sth->execute(@bind_vals) or
		       die "Unable to select one: ".$dbh->errstr();
		   my $results = $sth->fetchall_arrayref([0]);
		   $sth->finish();
		   return $results;
	       });
    return (ref($results) and ref($results->[0]))?$results->[0][0]:undef;
}

=item prepare_execute

	$schema->prepare_execute($sql,@bind_vals)

Prepares and executes a statement

=cut

sub prepare_execute {
    my ($self,$sql,@bind_vals) = @_;
    $self->storage->
	dbh_do(sub {
		   my ($s,$dbh) = @_;
		   my $sth = $dbh->
		       prepare_cached($sql,
                      {dbi_dummy => __FILE__.__LINE__ })
		       or die "Unable to prepare statement: $sql";
		   $sth->execute(@bind_vals) or
		       die "Unable to execute statement: ".$dbh->errstr();
		   $sth->finish();
	       });
}

=item sql_file_in_txn

C<sql_file_in_txn();>



=cut
sub sql_file_in_txn {
    my ($self,$fn) = @_;
    my $fh = open_compressed_file($fn) or
	die "Unable to open $fn for reading: $!";
    local $/;
    my $sql = <$fh>;
    defined($sql) or die "Unable to read from file: $!";
    $self->prepare_execute($sql);
}


=back

=cut

1;


__END__
