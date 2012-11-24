use utf8;
package Debbugs::DB::Result::SrcPkgAlias;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Debbugs::DB::Result::SrcPkgAlias

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

=head1 TABLE: C<src_pkg_alias>

=cut

__PACKAGE__->table("src_pkg_alias");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'src_pkg_alias_id_seq'

=head2 src_pkg_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 pkg_alias

  data_type: 'text'
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "src_pkg_alias_id_seq",
  },
  "src_pkg_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "pkg_alias",
  { data_type => "text", is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<pkg_alias_src_pkg_id_idx>

=over 4

=item * L</pkg_alias>

=item * L</src_pkg_id>

=back

=cut

__PACKAGE__->add_unique_constraint("pkg_alias_src_pkg_id_idx", ["pkg_alias", "src_pkg_id"]);

=head1 RELATIONS

=head2 src_pkg

Type: belongs_to

Related object: L<Debbugs::DB::Result::SrcPkg>

=cut

__PACKAGE__->belongs_to(
  "src_pkg",
  "Debbugs::DB::Result::SrcPkg",
  { id => "src_pkg_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07025 @ 2012-07-17 10:25:29
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:y5PGSPakrgG4u/oXIau2pw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
