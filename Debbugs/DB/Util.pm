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
use vars qw($VERSION $DEBUG %EXPORT_TAGS @EXPORT_OK @EXPORT);
use base qw(Exporter);

BEGIN{
     ($VERSION) = q$Revision$ =~ /^Revision:\s+([^\s+])/;
     $DEBUG = 0 unless defined $DEBUG;

     @EXPORT = ();
     %EXPORT_TAGS = (select => [qw(select_one)],
		    );
     @EXPORT_OK = ();
     Exporter::export_ok_tags(keys %EXPORT_TAGS);
     $EXPORT_TAGS{all} = [@EXPORT_OK];
}

=head2 select

Routines for select requests

=over

=item select_one

	select_one($dbh,$sql,@bind_vals)

Returns the first column from the first row returned from a select statement

=cut

sub select_one {
    my ($dbh,$sql,@bind_vals) = @_;
    my $sth = $dbh->
        prepare_cached($sql,
                      {dbi_dummy => __FILE__.__LINE__ })
        or die "Unable to prepare statement: $sql";
    $sth->execute(@bind_vals) or
        die "Unable to select one: ".$dbh->errstr();
    my $results = $sth->fetchall_arrayref([0]);
    $sth->finish();
    return (ref($results) and ref($results->[0]))?$results->[0][0]:undef;
}


=back

=cut

1;


__END__
