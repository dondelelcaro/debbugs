use utf8;
package Debbugs::DB::Result::Tag;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Debbugs::DB::Result::Tag - Bug tags

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

=head1 TABLE: C<tag>

=cut

__PACKAGE__->table("tag");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'tag_id_seq'

Tag id

=head2 tag

  data_type: 'text'
  is_nullable: 0

Tag name

=head2 obsolete

  data_type: 'boolean'
  default_value: false
  is_nullable: 1

Whether a tag is obsolete (should not be set on new bugs)

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "tag_id_seq",
  },
  "tag",
  { data_type => "text", is_nullable => 0 },
  "obsolete",
  { data_type => "boolean", default_value => \"false", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<tag_tag_key>

=over 4

=item * L</tag>

=back

=cut

__PACKAGE__->add_unique_constraint("tag_tag_key", ["tag"]);

=head1 RELATIONS

=head2 bug_tags

Type: has_many

Related object: L<Debbugs::DB::Result::BugTag>

=cut

__PACKAGE__->has_many(
  "bug_tags",
  "Debbugs::DB::Result::BugTag",
  { "foreign.tag" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07042 @ 2014-11-30 21:56:51
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:HH2aKSj4xl+co6qffSdrrQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
