use utf8;
package Debbugs::DB::Result::BugVer;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Debbugs::DB::Result::BugVer

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

=head1 TABLE: C<bug_ver>

=cut

__PACKAGE__->table("bug_ver");

=head1 ACCESSORS

=head2 bug_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 ver_string

  data_type: 'text'
  is_nullable: 1

=head2 src_pkg_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 src_ver_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 found

  data_type: 'boolean'
  default_value: true
  is_nullable: 0

=head2 creation

  data_type: 'timestamp with time zone'
  default_value: current_timestamp
  is_nullable: 0
  original: {default_value => \"now()"}

=head2 last_modified

  data_type: 'timestamp with time zone'
  default_value: current_timestamp
  is_nullable: 0
  original: {default_value => \"now()"}

=cut

__PACKAGE__->add_columns(
  "bug_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "ver_string",
  { data_type => "text", is_nullable => 1 },
  "src_pkg_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "src_ver_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "found",
  { data_type => "boolean", default_value => \"true", is_nullable => 0 },
  "creation",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
  "last_modified",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
);

=head1 UNIQUE CONSTRAINTS

=head2 C<bug_ver_bug_id_ver_string_found_idx>

=over 4

=item * L</bug_id>

=item * L</ver_string>

=item * L</found>

=back

=cut

__PACKAGE__->add_unique_constraint(
  "bug_ver_bug_id_ver_string_found_idx",
  ["bug_id", "ver_string", "found"],
);

=head1 RELATIONS

=head2 bug

Type: belongs_to

Related object: L<Debbugs::DB::Result::Bug>

=cut

__PACKAGE__->belongs_to(
  "bug",
  "Debbugs::DB::Result::Bug",
  { id => "bug_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 src_pkg

Type: belongs_to

Related object: L<Debbugs::DB::Result::SrcPkg>

=cut

__PACKAGE__->belongs_to(
  "src_pkg",
  "Debbugs::DB::Result::SrcPkg",
  { id => "src_pkg_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);

=head2 src_ver

Type: belongs_to

Related object: L<Debbugs::DB::Result::SrcVer>

=cut

__PACKAGE__->belongs_to(
  "src_ver",
  "Debbugs::DB::Result::SrcVer",
  { id => "src_ver_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);


# Created by DBIx::Class::Schema::Loader v0.07025 @ 2012-11-23 17:41:43
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:JMDsn7GGxoQ001KYUOyyTw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
