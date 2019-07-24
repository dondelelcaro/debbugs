use utf8;
package Debbugs::DB::Result::SrcVer;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Debbugs::DB::Result::SrcVer - Source Package versions

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

=head1 TABLE: C<src_ver>

=cut

__PACKAGE__->table("src_ver");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'src_ver_id_seq'

Source package version id

=head2 src_pkg

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

Source package id (matches src_pkg table)

=head2 ver

  data_type: 'debversion'
  is_nullable: 0

Version of the source package

=head2 maintainer

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

Maintainer id (matches maintainer table)

=head2 upload_date

  data_type: 'timestamp with time zone'
  default_value: current_timestamp
  is_nullable: 0
  original: {default_value => \"now()"}

Date this version of the source package was uploaded

=head2 based_on

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

Source package version this version is based on

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "src_ver_id_seq",
  },
  "src_pkg",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "ver",
  { data_type => "debversion", is_nullable => 0 },
  "maintainer",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "upload_date",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
  "based_on",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<src_ver_src_pkg_id_ver>

=over 4

=item * L</src_pkg>

=item * L</ver>

=back

=cut

__PACKAGE__->add_unique_constraint("src_ver_src_pkg_id_ver", ["src_pkg", "ver"]);

=head1 RELATIONS

=head2 based_on

Type: belongs_to

Related object: L<Debbugs::DB::Result::SrcVer>

=cut

__PACKAGE__->belongs_to(
  "based_on",
  "Debbugs::DB::Result::SrcVer",
  { id => "based_on" },
  {
    is_deferrable => 0,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);

=head2 bin_vers

Type: has_many

Related object: L<Debbugs::DB::Result::BinVer>

=cut

__PACKAGE__->has_many(
  "bin_vers",
  "Debbugs::DB::Result::BinVer",
  { "foreign.src_ver" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 bug_vers

Type: has_many

Related object: L<Debbugs::DB::Result::BugVer>

=cut

__PACKAGE__->has_many(
  "bug_vers",
  "Debbugs::DB::Result::BugVer",
  { "foreign.src_ver" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 maintainer

Type: belongs_to

Related object: L<Debbugs::DB::Result::Maintainer>

=cut

__PACKAGE__->belongs_to(
  "maintainer",
  "Debbugs::DB::Result::Maintainer",
  { id => "maintainer" },
  {
    is_deferrable => 0,
    join_type     => "LEFT",
    on_delete     => "SET NULL",
    on_update     => "CASCADE",
  },
);

=head2 src_associations

Type: has_many

Related object: L<Debbugs::DB::Result::SrcAssociation>

=cut

__PACKAGE__->has_many(
  "src_associations",
  "Debbugs::DB::Result::SrcAssociation",
  { "foreign.source" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
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

=head2 src_vers

Type: has_many

Related object: L<Debbugs::DB::Result::SrcVer>

=cut

__PACKAGE__->has_many(
  "src_vers",
  "Debbugs::DB::Result::SrcVer",
  { "foreign.based_on" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07042 @ 2014-11-30 21:56:51
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:gY5LidUaQeuJ5AnN06CfKQ


sub sqlt_deploy_hook {
    my ($self, $sqlt_table) = @_;
    $sqlt_table->schema->
	add_procedure(name => 'src_ver_to_src_pkg',
		      sql => <<'EOF',
CREATE OR REPLACE FUNCTION src_ver_to_src_pkg(src_ver INT) RETURNS INT
  AS $src_ver_to_src_pkg$
  DECLARE
  src_pkg int;
  BEGIN
	SELECT sv.src_pkg INTO STRICT src_pkg
	       FROM src_ver sv WHERE sv.id=src_ver;
	RETURN src_pkg;
  END
  $src_ver_to_src_pkg$ LANGUAGE plpgsql;
EOF
		     );
}
# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
