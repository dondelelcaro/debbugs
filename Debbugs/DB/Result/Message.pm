use utf8;
package Debbugs::DB::Result::Message;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Debbugs::DB::Result::Message - Messages sent to bugs

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 COMPONENTS LOADED

=over 4

=item * L<DBIx::Class::InflateColumn::DateTime>

=back

=cut

__PACKAGE__->load_components("InflateColumn::DateTime");

=head1 TABLE: C<message>

=cut

__PACKAGE__->table("message");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'message_id_seq'

Message id

=head2 msgid

  data_type: 'text'
  is_nullable: 1

Message id header

=head2 from_complete

  data_type: 'text'
  is_nullable: 1

Complete from header of message

=head2 from_addr

  data_type: 'text'
  is_nullable: 1

Address(es) of From: headers

=head2 to_complete

  data_type: 'text'
  is_nullable: 1

Complete to header of message

=head2 to_addr

  data_type: 'text'
  is_nullable: 1

Address(es) of To: header

=head2 subject

  data_type: 'text'
  default_value: (empty string)
  is_nullable: 0

Subject of the message

=head2 sent_date

  data_type: 'timestamp with time zone'
  is_nullable: 1

Time/date message was sent (from Date header)

=head2 refs

  data_type: 'text'
  default_value: (empty string)
  is_nullable: 0

Contents of References: header

=head2 spam_score

  data_type: 'double precision'
  is_nullable: 1

Spam score from spamassassin

=head2 is_spam

  data_type: 'boolean'
  default_value: false
  is_nullable: 1

True if this message was spam and should not be shown

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "message_id_seq",
  },
  "msgid",
  { data_type => "text", is_nullable => 1 },
  "from_complete",
  { data_type => "text", is_nullable => 1 },
  "from_addr",
  { data_type => "text", is_nullable => 1 },
  "to_complete",
  { data_type => "text", is_nullable => 1 },
  "to_addr",
  { data_type => "text", is_nullable => 1 },
  "subject",
  { data_type => "text", default_value => "", is_nullable => 0 },
  "sent_date",
  { data_type => "timestamp with time zone", is_nullable => 1 },
  "refs",
  { data_type => "text", default_value => "", is_nullable => 0 },
  "spam_score",
  { data_type => "double precision", is_nullable => 1 },
  "is_spam",
  { data_type => "boolean", default_value => \"false", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 bug_messages

Type: has_many

Related object: L<Debbugs::DB::Result::BugMessage>

=cut

__PACKAGE__->has_many(
  "bug_messages",
  "Debbugs::DB::Result::BugMessage",
  { "foreign.message" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 message_correspondents

Type: has_many

Related object: L<Debbugs::DB::Result::MessageCorrespondent>

=cut

__PACKAGE__->has_many(
  "message_correspondents",
  "Debbugs::DB::Result::MessageCorrespondent",
  { "foreign.message" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 message_refs_messages

Type: has_many

Related object: L<Debbugs::DB::Result::MessageRef>

=cut

__PACKAGE__->has_many(
  "message_refs_messages",
  "Debbugs::DB::Result::MessageRef",
  { "foreign.message" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 message_refs_refs

Type: has_many

Related object: L<Debbugs::DB::Result::MessageRef>

=cut

__PACKAGE__->has_many(
  "message_refs_refs",
  "Debbugs::DB::Result::MessageRef",
  { "foreign.refs" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07025 @ 2013-01-22 21:35:43
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:M6k3YCfOyYLnQJ+qBcoJlQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
