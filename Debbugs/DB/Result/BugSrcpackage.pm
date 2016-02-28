use utf8;
package Debbugs::DB::Result::BugSrcpackage;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Debbugs::DB::Result::BugSrcpackage - Bug <-> source package mapping

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

=head1 TABLE: C<bug_srcpackage>

=cut

__PACKAGE__->table("bug_srcpackage");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'bug_srcpackage_id_seq'

=head2 bug

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

Bug id (matches bug)

=head2 src_pkg

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

Source package id (matches src_pkg)

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "bug_srcpackage_id_seq",
  },
  "bug",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "src_pkg",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<bug_srcpackage_id_pkg>

=over 4

=item * L</bug>

=item * L</src_pkg>

=back

=cut

__PACKAGE__->add_unique_constraint("bug_srcpackage_id_pkg", ["bug", "src_pkg"]);

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

=head2 src_pkg

Type: belongs_to

Related object: L<Debbugs::DB::Result::SrcPkg>

=cut

__PACKAGE__->belongs_to(
  "src_pkg",
  "Debbugs::DB::Result::SrcPkg",
  { id => "src_pkg" },
  { is_deferrable => 0, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07042 @ 2014-11-30 21:56:51
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:rkrGE3oLGWe28oXEFt4UFg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
