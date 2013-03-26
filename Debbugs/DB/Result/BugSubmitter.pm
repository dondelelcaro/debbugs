use utf8;
package Debbugs::DB::Result::BugSubmitter;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Debbugs::DB::Result::BugSubmitter - Submitter of a bug (connects to correspondent)

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

=head1 TABLE: C<bug_submitter>

=cut

__PACKAGE__->table("bug_submitter");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'bug_submitter_id_seq'

Bug Submitter ID

=head2 bug

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

Bug which was submitted by this submitter

=head2 submitter

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

Bug submitter (connects to correspondent)

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "bug_submitter_id_seq",
  },
  "bug",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "submitter",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<bug_submitter_bug_submitter_idx>

=over 4

=item * L</bug>

=item * L</submitter>

=back

=cut

__PACKAGE__->add_unique_constraint("bug_submitter_bug_submitter_idx", ["bug", "submitter"]);

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

=head2 submitter

Type: belongs_to

Related object: L<Debbugs::DB::Result::Correspondent>

=cut

__PACKAGE__->belongs_to(
  "submitter",
  "Debbugs::DB::Result::Correspondent",
  { id => "submitter" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07025 @ 2013-03-25 18:43:53
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:xlPjKuzFWXqJs1TxWZ+YSw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
