use utf8;
package Debbugs::DB::Result::MessageCorrespondent;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Debbugs::DB::Result::MessageCorrespondent - Linkage between correspondent and message

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

=head1 TABLE: C<message_correspondent>

=cut

__PACKAGE__->table("message_correspondent");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'message_correspondent_id_seq'

=head2 message

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

Message id (matches message)

=head2 correspondent

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

Correspondent (matches correspondent)

=head2 correspondent_type

  data_type: 'enum'
  default_value: 'to'
  extra: {custom_type_name => "message_correspondent_type",list => ["to","from","envfrom","cc"]}
  is_nullable: 0

Type of correspondent (to, from, envfrom, cc, etc.)

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "message_correspondent_id_seq",
  },
  "message",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "correspondent",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "correspondent_type",
  {
    data_type => "enum",
    default_value => "to",
    extra => {
      custom_type_name => "message_correspondent_type",
      list => ["to", "from", "envfrom", "cc"],
    },
    is_nullable => 0,
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<message_correspondent_message_correspondent_correspondent_t_idx>

=over 4

=item * L</message>

=item * L</correspondent>

=item * L</correspondent_type>

=back

=cut

__PACKAGE__->add_unique_constraint(
  "message_correspondent_message_correspondent_correspondent_t_idx",
  ["message", "correspondent", "correspondent_type"],
);

=head1 RELATIONS

=head2 correspondent

Type: belongs_to

Related object: L<Debbugs::DB::Result::Correspondent>

=cut

__PACKAGE__->belongs_to(
  "correspondent",
  "Debbugs::DB::Result::Correspondent",
  { id => "correspondent" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

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


# Created by DBIx::Class::Schema::Loader v0.07025 @ 2013-03-22 21:34:19
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Fyy71zaVBm59n1blNwJ23w


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
