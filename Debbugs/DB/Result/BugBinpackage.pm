use utf8;
package Debbugs::DB::Result::BugBinpackage;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Debbugs::DB::Result::BugBinpackage - Bug <-> binary package mapping

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

=head1 TABLE: C<bug_binpackage>

=cut

__PACKAGE__->table("bug_binpackage");

=head1 ACCESSORS

=head2 bug

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

Bug id (matches bug)

=head2 bin_pkg

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

Binary package id (matches bin_pkg)

=cut

__PACKAGE__->add_columns(
  "bug",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "bin_pkg",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);

=head1 UNIQUE CONSTRAINTS

=head2 C<bug_binpackage_bin_pkg_bug_idx>

=over 4

=item * L</bin_pkg>

=item * L</bug>

=back

=cut

__PACKAGE__->add_unique_constraint("bug_binpackage_bin_pkg_bug_idx", ["bin_pkg", "bug"]);

=head2 C<bug_binpackage_id_pkg>

=over 4

=item * L</bug>

=item * L</bin_pkg>

=back

=cut

__PACKAGE__->add_unique_constraint("bug_binpackage_id_pkg", ["bug", "bin_pkg"]);

=head1 RELATIONS

=head2 bin_pkg

Type: belongs_to

Related object: L<Debbugs::DB::Result::BinPkg>

=cut

__PACKAGE__->belongs_to(
  "bin_pkg",
  "Debbugs::DB::Result::BinPkg",
  { id => "bin_pkg" },
  { is_deferrable => 0, on_delete => "CASCADE", on_update => "CASCADE" },
);

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


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2019-01-01 17:29:32
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:gEYqmJfiJJtRYFzIYut3Fg


sub sqlt_deploy_hook {
    my ($self, $sqlt_table) = @_;
    $sqlt_table->add_index(name => 'bug_binpackage_bin_pkg_idx',
			   fields => [qw(bin_pkg)],
			  );
}

1;
