use utf8;
package Debbugs::DB::Result::Maintainer;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Debbugs::DB::Result::Maintainer

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

=head2 name

  data_type: 'text'
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
    sequence          => "maintainer_id_seq",
  },
  "name",
  { data_type => "text", is_nullable => 0 },
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

=head2 src_vers

Type: has_many

Related object: L<Debbugs::DB::Result::SrcVer>

=cut

__PACKAGE__->has_many(
  "src_vers",
  "Debbugs::DB::Result::SrcVer",
  { "foreign.maintainer_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07025 @ 2012-11-25 00:09:07
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:XOB1oEoov4hXMzTD4A7KHg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
