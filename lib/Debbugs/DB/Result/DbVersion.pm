use utf8;
package Debbugs::DB::Result::DbVersion;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Debbugs::DB::Result::DbVersion - Version of the Database Schema

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

=head1 TABLE: C<db_version>

=cut

__PACKAGE__->table("db_version");

=head1 ACCESSORS

=head2 version

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

Version number of the database

=head2 date

  data_type: 'timestamp with time zone'
  default_value: current_timestamp
  is_nullable: 1
  original: {default_value => \"now()"}

Date the database was upgraded to this version

=head2 metadata

  data_type: 'jsonb'
  default_value: jsonb_object('{}'::text[])
  is_nullable: 0

Details about how the database was upgraded to this version

=cut

__PACKAGE__->add_columns(
  "version",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
  "date",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 1,
    original      => { default_value => \"now()" },
  },
  "metadata",
  {
    data_type     => "jsonb",
    default_value => \"jsonb_object('{}'::text[])",
    is_nullable   => 0,
  },
);

=head1 UNIQUE CONSTRAINTS

=head2 C<db_version_version_key>

=over 4

=item * L</version>

=back

=cut

__PACKAGE__->add_unique_constraint("db_version_version_key", ["version"]);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2020-08-01 13:43:06
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:xf/jizKdQyo+8jAbc0i3cg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
