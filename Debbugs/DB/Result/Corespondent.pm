use utf8;
package Debbugs::DB::Result::Corespondent;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Debbugs::DB::Result::Corespondent

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

=head1 TABLE: C<corespondent>

=cut

__PACKAGE__->table("corespondent");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'corespondent_id_seq'

=head2 addr

  data_type: 'text'
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "corespondent_id_seq",
  },
  "addr",
  { data_type => "text", is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<corespondent_addr_key>

=over 4

=item * L</addr>

=back

=cut

__PACKAGE__->add_unique_constraint("corespondent_addr_key", ["addr"]);

=head1 RELATIONS

=head2 message_corespondents

Type: has_many

Related object: L<Debbugs::DB::Result::MessageCorespondent>

=cut

__PACKAGE__->has_many(
  "message_corespondents",
  "Debbugs::DB::Result::MessageCorespondent",
  { "foreign.corespondent" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07025 @ 2012-11-29 15:37:55
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:v3bUQ+IEbhl9Z9+g6uQVDw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
