use utf8;
package Debbugs::DB::Result::MessageRef;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Debbugs::DB::Result::MessageRef

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

=head2 message

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 refs

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "message",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "refs",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);

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


# Created by DBIx::Class::Schema::Loader v0.07025 @ 2012-11-29 15:37:55
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:uCScDuC5TprnuyEjg25eXg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
