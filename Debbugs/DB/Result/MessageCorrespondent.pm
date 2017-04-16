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

=item * L<DBIx::Class::TimeStamp>

=back

=cut

__PACKAGE__->load_components("InflateColumn::DateTime", "TimeStamp");

=head1 TABLE: C<message_correspondent>

=cut

__PACKAGE__->table("message_correspondent");

=head1 ACCESSORS

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
  extra: {custom_type_name => "message_correspondent_type",list => ["to","from","envfrom","cc","recv"]}
  is_nullable: 0

Type of correspondent (to, from, envfrom, cc, etc.)

=cut

__PACKAGE__->add_columns(
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
      list => ["to", "from", "envfrom", "cc", "recv"],
    },
    is_nullable => 0,
  },
);

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
  { is_deferrable => 0, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 message

Type: belongs_to

Related object: L<Debbugs::DB::Result::Message>

=cut

__PACKAGE__->belongs_to(
  "message",
  "Debbugs::DB::Result::Message",
  { id => "message" },
  { is_deferrable => 0, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07046 @ 2017-03-07 19:03:32
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:kIhya7skj4ZNM3DkC+gAPw


sub sqlt_deploy_hook {
    my ($self, $sqlt_table) = @_;
    for my $idx (qw(correspondent message)) {
	$sqlt_table->add_index(name => 'message_correspondent_idx'.$idx,
			       fields => [$idx]);
    }
}

1;
