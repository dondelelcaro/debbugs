use utf8;
package Debbugs::DB::Result::BinAssociation;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Debbugs::DB::Result::BinAssociation

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

=head1 TABLE: C<bin_associations>

=cut

__PACKAGE__->table("bin_associations");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'bin_associations_id_seq'

=head2 suite

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 bin

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 created

  data_type: 'timestamp with time zone'
  default_value: current_timestamp
  is_nullable: 0
  original: {default_value => \"now()"}

=head2 modified

  data_type: 'timestamp with time zone'
  default_value: current_timestamp
  is_nullable: 0
  original: {default_value => \"now()"}

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "bin_associations_id_seq",
  },
  "suite",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "bin",
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

=head1 RELATIONS

=head2 bin

Type: belongs_to

Related object: L<Debbugs::DB::Result::BinVer>

=cut

__PACKAGE__->belongs_to(
  "bin",
  "Debbugs::DB::Result::BinVer",
  { id => "bin" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 suite

Type: belongs_to

Related object: L<Debbugs::DB::Result::Suite>

=cut

__PACKAGE__->belongs_to(
  "suite",
  "Debbugs::DB::Result::Suite",
  { id => "suite" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07025 @ 2012-11-25 00:09:07
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:/cCrHn40eoiD6aOPmXU8dw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
