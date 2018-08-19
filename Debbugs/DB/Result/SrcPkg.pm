use utf8;
package Debbugs::DB::Result::SrcPkg;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Debbugs::DB::Result::SrcPkg - Source packages

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

=head1 TABLE: C<src_pkg>

=cut

__PACKAGE__->table("src_pkg");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'src_pkg_id_seq'

Source package id

=head2 pkg

  data_type: 'text'
  is_nullable: 0

Source package name

=head2 pseduopkg

  data_type: 'boolean'
  default_value: false
  is_nullable: 0

=head2 alias_of

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

Source package id which this source package is an alias of

=head2 creation

  data_type: 'timestamp with time zone'
  default_value: current_timestamp
  is_nullable: 0
  original: {default_value => \"now()"}

=head2 disabled

  data_type: 'timestamp with time zone'
  default_value: infinity
  is_nullable: 0

=head2 last_modified

  data_type: 'timestamp with time zone'
  default_value: current_timestamp
  is_nullable: 0
  original: {default_value => \"now()"}

=head2 obsolete

  data_type: 'boolean'
  default_value: false
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "src_pkg_id_seq",
  },
  "pkg",
  { data_type => "text", is_nullable => 0 },
  "pseduopkg",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "alias_of",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "creation",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
  "disabled",
  {
    data_type     => "timestamp with time zone",
    default_value => "infinity",
    is_nullable   => 0,
  },
  "last_modified",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
  "obsolete",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<src_pkg_pkg_disabled>

=over 4

=item * L</pkg>

=item * L</disabled>

=back

=cut

__PACKAGE__->add_unique_constraint("src_pkg_pkg_disabled", ["pkg", "disabled"]);

=head1 RELATIONS

=head2 alias_of

Type: belongs_to

Related object: L<Debbugs::DB::Result::SrcPkg>

=cut

__PACKAGE__->belongs_to(
  "alias_of",
  "Debbugs::DB::Result::SrcPkg",
  { id => "alias_of" },
  {
    is_deferrable => 0,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);

=head2 bin_pkg_src_pkgs

Type: has_many

Related object: L<Debbugs::DB::Result::BinPkgSrcPkg>

=cut

__PACKAGE__->has_many(
  "bin_pkg_src_pkgs",
  "Debbugs::DB::Result::BinPkgSrcPkg",
  { "foreign.src_pkg" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 bug_affects_srcpackages

Type: has_many

Related object: L<Debbugs::DB::Result::BugAffectsSrcpackage>

=cut

__PACKAGE__->has_many(
  "bug_affects_srcpackages",
  "Debbugs::DB::Result::BugAffectsSrcpackage",
  { "foreign.src_pkg" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 bug_srcpackages

Type: has_many

Related object: L<Debbugs::DB::Result::BugSrcpackage>

=cut

__PACKAGE__->has_many(
  "bug_srcpackages",
  "Debbugs::DB::Result::BugSrcpackage",
  { "foreign.src_pkg" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 bug_vers

Type: has_many

Related object: L<Debbugs::DB::Result::BugVer>

=cut

__PACKAGE__->has_many(
  "bug_vers",
  "Debbugs::DB::Result::BugVer",
  { "foreign.src_pkg" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 src_pkgs

Type: has_many

Related object: L<Debbugs::DB::Result::SrcPkg>

=cut

__PACKAGE__->has_many(
  "src_pkgs",
  "Debbugs::DB::Result::SrcPkg",
  { "foreign.alias_of" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 src_vers

Type: has_many

Related object: L<Debbugs::DB::Result::SrcVer>

=cut

__PACKAGE__->has_many(
  "src_vers",
  "Debbugs::DB::Result::SrcVer",
  { "foreign.src_pkg" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07048 @ 2018-04-18 16:55:56
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:fMMA9wnkPIdT5eiUIkLxqg


sub sqlt_deploy_hook {
    my ($self, $sqlt_table) = @_;
    $sqlt_table->add_index(name => 'src_pkg_pkg',
			   fields => 'pkg',
			  );
}
1;
