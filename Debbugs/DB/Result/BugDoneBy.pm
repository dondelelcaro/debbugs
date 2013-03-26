use utf8;
package Debbugs::DB::Result::BugDoneBy;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Debbugs::DB::Result::BugDoneBy - Correspondent who finished this bug (emailed -done)

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

=head1 TABLE: C<bug_done_by>

=cut

__PACKAGE__->table("bug_done_by");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'bug_done_by_id_seq'

Bug Done By ID

=head2 bug

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

Bug number which was done

=head2 done_by

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

Bug finisher (connects to correspondent)

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "bug_done_by_id_seq",
  },
  "bug",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "done_by",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<bug_done_by_bug_done_by_idx>

=over 4

=item * L</bug>

=item * L</done_by>

=back

=cut

__PACKAGE__->add_unique_constraint("bug_done_by_bug_done_by_idx", ["bug", "done_by"]);

=head1 RELATIONS

=head2 bug

Type: belongs_to

Related object: L<Debbugs::DB::Result::Bug>

=cut

__PACKAGE__->belongs_to(
  "bug",
  "Debbugs::DB::Result::Bug",
  { id => "bug" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 done_by

Type: belongs_to

Related object: L<Debbugs::DB::Result::Correspondent>

=cut

__PACKAGE__->belongs_to(
  "done_by",
  "Debbugs::DB::Result::Correspondent",
  { id => "done_by" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07025 @ 2013-03-25 18:43:53
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:CBqbxeroNjyMIoDmjnAlbw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
