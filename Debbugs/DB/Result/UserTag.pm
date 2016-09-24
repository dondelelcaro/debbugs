use utf8;
package Debbugs::DB::Result::UserTag;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Debbugs::DB::Result::UserTag - User bug tags

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

=head1 TABLE: C<user_tag>

=cut

__PACKAGE__->table("user_tag");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'user_tag_id_seq'

User bug tag id

=head2 tag

  data_type: 'text'
  is_nullable: 0

User bug tag name

=head2 correspondent

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

User bug tag correspondent

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "user_tag_id_seq",
  },
  "tag",
  { data_type => "text", is_nullable => 0 },
  "correspondent",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<user_tag_tag_correspondent>

=over 4

=item * L</tag>

=item * L</correspondent>

=back

=cut

__PACKAGE__->add_unique_constraint("user_tag_tag_correspondent", ["tag", "correspondent"]);

=head1 RELATIONS

=head2 bug_user_tags

Type: has_many

Related object: L<Debbugs::DB::Result::BugUserTag>

=cut

__PACKAGE__->has_many(
  "bug_user_tags",
  "Debbugs::DB::Result::BugUserTag",
  { "foreign.user_tag" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 correspondent

Type: belongs_to

Related object: L<Debbugs::DB::Result::Correspondent>

=cut

__PACKAGE__->belongs_to(
  "correspondent",
  "Debbugs::DB::Result::Correspondent",
  { id => "correspondent" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader v0.07045 @ 2016-09-24 14:51:07
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:ZPmTBeTue62dG2NdQdPrQg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
