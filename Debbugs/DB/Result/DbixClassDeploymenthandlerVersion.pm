use utf8;
package Debbugs::DB::Result::DbixClassDeploymenthandlerVersion;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Debbugs::DB::Result::DbixClassDeploymenthandlerVersion

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

=head1 TABLE: C<dbix_class_deploymenthandler_versions>

=cut

__PACKAGE__->table("dbix_class_deploymenthandler_versions");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'dbix_class_deploymenthandler_versions_id_seq'

=head2 version

  data_type: 'varchar'
  is_nullable: 0
  size: 50

=head2 ddl

  data_type: 'text'
  is_nullable: 1

=head2 upgrade_sql

  data_type: 'text'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "dbix_class_deploymenthandler_versions_id_seq",
  },
  "version",
  { data_type => "varchar", is_nullable => 0, size => 50 },
  "ddl",
  { data_type => "text", is_nullable => 1 },
  "upgrade_sql",
  { data_type => "text", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<dbix_class_deploymenthandler_versions_version>

=over 4

=item * L</version>

=back

=cut

__PACKAGE__->add_unique_constraint("dbix_class_deploymenthandler_versions_version", ["version"]);


# Created by DBIx::Class::Schema::Loader v0.07036 @ 2013-11-06 21:19:42
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:d62Bah1PHAy1ZMhIt2HeIA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
