use utf8;
package Debbugs::DB::Result::BugTag;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Debbugs::DB::Result::BugTag - Bug <-> tag mapping

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

=head1 TABLE: C<bug_tag>

=cut

__PACKAGE__->table("bug_tag");

=head1 ACCESSORS

=head2 bug

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

Bug id (matches bug)

=head2 tag

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

Tag id (matches tag)

=cut

__PACKAGE__->add_columns(
  "bug",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "tag",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);

=head1 UNIQUE CONSTRAINTS

=head2 C<bug_tag_bug_tag>

=over 4

=item * L</bug>

=item * L</tag>

=back

=cut

__PACKAGE__->add_unique_constraint("bug_tag_bug_tag", ["bug", "tag"]);

=head1 RELATIONS

=head2 bug

Type: belongs_to

Related object: L<Debbugs::DB::Result::Bug>

=cut

__PACKAGE__->belongs_to(
  "bug",
  "Debbugs::DB::Result::Bug",
  { id => "bug" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);

=head2 tag

Type: belongs_to

Related object: L<Debbugs::DB::Result::Tag>

=cut

__PACKAGE__->belongs_to(
  "tag",
  "Debbugs::DB::Result::Tag",
  { id => "tag" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader v0.07046 @ 2017-03-04 10:59:03
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:yyHP5f8zAxn/AdjOCr8WAg


sub sqlt_deploy_hook {
    my ($self, $sqlt_table) = @_;
    $sqlt_table->add_index(name => 'bug_tag_tag',
			   fields => [qw(tag)],
			  );
}

1;
