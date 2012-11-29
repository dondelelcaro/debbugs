use utf8;
package Debbugs::DB::Result::MessageCorespondent;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Debbugs::DB::Result::MessageCorespondent

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

=head1 TABLE: C<message_corespondent>

=cut

__PACKAGE__->table("message_corespondent");

=head1 ACCESSORS

=head2 message

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 corespondent

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 corespondent_type

  data_type: 'enum'
  default_value: 'to'
  extra: {custom_type_name => "message_corespondent_type",list => ["to","from","envfrom","cc"]}
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "message",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "corespondent",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "corespondent_type",
  {
    data_type => "enum",
    default_value => "to",
    extra => {
      custom_type_name => "message_corespondent_type",
      list => ["to", "from", "envfrom", "cc"],
    },
    is_nullable => 0,
  },
);

=head1 UNIQUE CONSTRAINTS

=head2 C<message_corespondent_message_corespondent_corespondent_type_idx>

=over 4

=item * L</message>

=item * L</corespondent>

=item * L</corespondent_type>

=back

=cut

__PACKAGE__->add_unique_constraint(
  "message_corespondent_message_corespondent_corespondent_type_idx",
  ["message", "corespondent", "corespondent_type"],
);

=head1 RELATIONS

=head2 corespondent

Type: belongs_to

Related object: L<Debbugs::DB::Result::Corespondent>

=cut

__PACKAGE__->belongs_to(
  "corespondent",
  "Debbugs::DB::Result::Corespondent",
  { id => "corespondent" },
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


# Created by DBIx::Class::Schema::Loader v0.07025 @ 2012-11-29 15:37:55
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Qc6K0oFKcXSuaQhTBgRCaw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
