# This module is part of debbugs, and is released
# under the terms of the GPL version 2, or any later version. See the
# file README and COPYING for more information.
# Copyright 2017 by Don Armstrong <don@donarmstrong.com>.
use utf8;
package Debbugs::DB::ResultSet::Message;

=head1 NAME

Debbugs::DB::ResultSet::Message - Message table actions

=head1 SYNOPSIS



=head1 DESCRIPTION



=cut

use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

sub get_message_id {
    my ($self,$msg_id,$from,$to,$subject) = @_;
    return $self->result_source->schema->
	select_one(<<'SQL',@_,@_);
WITH ins AS (
INSERT INTO message (msgid,from_complete,to_complete,subject) VALUES (?,?,?,?)
 ON CONFLICT (msgid,from_complete,to_complete,subject) DO NOTHING RETURNING id
)
SELECT id FROM ins
UNION ALL
SELECT id FROM correspondent WHERE msgid=? AND from_complete = ?
AND to_complete = ? AND subject = ?
LIMIT 1;
SQL
}



1;

__END__
