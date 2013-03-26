use utf8;
package Debbugs::DB::Result::BugSeverity;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Debbugs::DB::Result::BugSeverity - Bug <-> tag mapping

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

=head1 TABLE: C<bug_severity>

=cut

__PACKAGE__->table("bug_severity");

=head1 ACCESSORS

=head2 bug

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

Bug id (matches bug)

=head2 severity_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

Severity id (matches severity)

=cut

__PACKAGE__->add_columns(
  "bug",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "severity_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</bug>

=back

=cut

__PACKAGE__->set_primary_key("bug");

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

=head2 severity

Type: belongs_to

Related object: L<Debbugs::DB::Result::Severity>

=cut

__PACKAGE__->belongs_to(
  "severity",
  "Debbugs::DB::Result::Severity",
  { id => "severity_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07025 @ 2013-03-25 18:43:53
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:LOIST37qyS/Mh96uRH7ZcQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
