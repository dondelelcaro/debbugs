use utf8;
package Debbugs::DB::Result::BinPkg;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Debbugs::DB::Result::BinPkg - Binary packages

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

=head1 TABLE: C<bin_pkg>

=cut

__PACKAGE__->table("bin_pkg");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'bin_pkg_id_seq'

Binary package id

=head2 pkg

  data_type: 'text'
  is_nullable: 0

Binary package name

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "bin_pkg_id_seq",
  },
  "pkg",
  { data_type => "text", is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<bin_pkg_pkg_key>

=over 4

=item * L</pkg>

=back

=cut

__PACKAGE__->add_unique_constraint("bin_pkg_pkg_key", ["pkg"]);

=head1 RELATIONS

=head2 bin_pkg_src_pkgs

Type: has_many

Related object: L<Debbugs::DB::Result::BinPkgSrcPkg>

=cut

__PACKAGE__->has_many(
  "bin_pkg_src_pkgs",
  "Debbugs::DB::Result::BinPkgSrcPkg",
  { "foreign.bin_pkg" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 bin_vers

Type: has_many

Related object: L<Debbugs::DB::Result::BinVer>

=cut

__PACKAGE__->has_many(
  "bin_vers",
  "Debbugs::DB::Result::BinVer",
  { "foreign.bin_pkg" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 bug_affects_binpackages

Type: has_many

Related object: L<Debbugs::DB::Result::BugAffectsBinpackage>

=cut

__PACKAGE__->has_many(
  "bug_affects_binpackages",
  "Debbugs::DB::Result::BugAffectsBinpackage",
  { "foreign.bin_pkg" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 bug_binpackages

Type: has_many

Related object: L<Debbugs::DB::Result::BugBinpackage>

=cut

__PACKAGE__->has_many(
  "bug_binpackages",
  "Debbugs::DB::Result::BugBinpackage",
  { "foreign.bin_pkg" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07048 @ 2018-04-18 16:55:56
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Uoaf3KzTvRYIf33q7tBnZw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
