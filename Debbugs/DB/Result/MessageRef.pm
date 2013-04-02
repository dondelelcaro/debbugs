use utf8;
package Debbugs::DB::Result::MessageRef;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Debbugs::DB::Result::MessageRef - Message references

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

=head1 TABLE: C<message_refs>

=cut

__PACKAGE__->table("message_refs");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'message_refs_id_seq'

=head2 message

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

Message id (matches message)

=head2 refs

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

Reference id (matches message)

=head2 inferred

  data_type: 'boolean'
  default_value: false
  is_nullable: 1

TRUE if this message reference was reconstructed; primarily of use for messages which lack In-Reply-To: or References: headers

=head2 primary_ref

  data_type: 'boolean'
  default_value: false
  is_nullable: 1

TRUE if this message->ref came from In-Reply-To: or similar.

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "message_refs_id_seq",
  },
  "message",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "refs",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "inferred",
  { data_type => "boolean", default_value => \"false", is_nullable => 1 },
  "primary_ref",
  { data_type => "boolean", default_value => \"false", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<message_refs_message_refs_idx>

=over 4

=item * L</message>

=item * L</refs>

=back

=cut

__PACKAGE__->add_unique_constraint("message_refs_message_refs_idx", ["message", "refs"]);

=head1 RELATIONS

=head2 message

Type: belongs_to

Related object: L<Debbugs::DB::Result::Message>

=cut

__PACKAGE__->belongs_to(
  "message",
  "Debbugs::DB::Result::Message",
  { id => "message" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 ref

Type: belongs_to

Related object: L<Debbugs::DB::Result::Message>

=cut

__PACKAGE__->belongs_to(
  "ref",
  "Debbugs::DB::Result::Message",
  { id => "refs" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07025 @ 2013-03-27 18:54:20
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:+vwRG2KAV0YTTXZE0Vv21A


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
