use utf8;
package Debbugs::DB::Result::SrcAssociation;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Debbugs::DB::Result::SrcAssociation - Source <-> suite associations

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

=head1 TABLE: C<src_associations>

=cut

__PACKAGE__->table("src_associations");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'src_associations_id_seq'

Source <-> suite association id

=head2 suite

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

Suite id (matches suite)

=head2 source

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

Source version id (matches src_ver)

=head2 created

  data_type: 'timestamp with time zone'
  default_value: current_timestamp
  is_nullable: 0
  original: {default_value => \"now()"}

Time this source package entered this suite

=head2 modified

  data_type: 'timestamp with time zone'
  default_value: current_timestamp
  is_nullable: 0
  original: {default_value => \"now()"}

Time this entry was modified

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "src_associations_id_seq",
  },
  "suite",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "source",
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

=head2 C<src_associations_source_suite>

=over 4

=item * L</source>

=item * L</suite>

=back

=cut

__PACKAGE__->add_unique_constraint("src_associations_source_suite", ["source", "suite"]);

=head1 RELATIONS

=head2 source

Type: belongs_to

Related object: L<Debbugs::DB::Result::SrcVer>

=cut

__PACKAGE__->belongs_to(
  "source",
  "Debbugs::DB::Result::SrcVer",
  { id => "source" },
  { is_deferrable => 0, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 suite

Type: belongs_to

Related object: L<Debbugs::DB::Result::Suite>

=cut

__PACKAGE__->belongs_to(
  "suite",
  "Debbugs::DB::Result::Suite",
  { id => "suite" },
  { is_deferrable => 0, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07045 @ 2016-11-24 08:52:49
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:B3gOeYD0JxOUtV92mBocZQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
