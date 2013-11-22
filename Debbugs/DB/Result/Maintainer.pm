use utf8;
package Debbugs::DB::Result::Maintainer;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Debbugs::DB::Result::Maintainer - Package maintainer names

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

=head1 TABLE: C<maintainer>

=cut

__PACKAGE__->table("maintainer");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'maintainer_id_seq'

Package maintainer id

=head2 name

  data_type: 'text'
  is_nullable: 0

Name of package maintainer

=head2 correspondent

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

Correspondent ID

=head2 created

  data_type: 'timestamp with time zone'
  default_value: current_timestamp
  is_nullable: 0
  original: {default_value => \"now()"}

Time maintainer record created

=head2 modified

  data_type: 'timestamp with time zone'
  default_value: current_timestamp
  is_nullable: 0
  original: {default_value => \"now()"}

Time maintainer record modified

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "maintainer_id_seq",
  },
  "name",
  { data_type => "text", is_nullable => 0 },
  "correspondent",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "created",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
  "modified",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<maintainer_name_key>

=over 4

=item * L</name>

=back

=cut

__PACKAGE__->add_unique_constraint("maintainer_name_key", ["name"]);

=head1 RELATIONS

=head2 correspondent

Type: belongs_to

Related object: L<Debbugs::DB::Result::Correspondent>

=cut

__PACKAGE__->belongs_to(
  "correspondent",
  "Debbugs::DB::Result::Correspondent",
  { id => "correspondent" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);

=head2 src_vers

Type: has_many

Related object: L<Debbugs::DB::Result::SrcVer>

=cut

__PACKAGE__->has_many(
  "src_vers",
  "Debbugs::DB::Result::SrcVer",
  { "foreign.maintainer" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07036 @ 2013-11-21 21:57:41
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:E1iNr1IKDcHDQYtmVdsoHA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
