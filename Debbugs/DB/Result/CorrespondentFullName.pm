use utf8;
package Debbugs::DB::Result::CorrespondentFullName;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Debbugs::DB::Result::CorrespondentFullName - Full names of BTS correspondents

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

=head1 TABLE: C<correspondent_full_name>

=cut

__PACKAGE__->table("correspondent_full_name");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'correspondent_full_name_id_seq'

Correspondent full name id

=head2 correspondent

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 full_name

  data_type: 'text'
  is_nullable: 0

Correspondent full name (includes e-mail address)

=head2 last_seen

  data_type: 'timestamp'
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
    sequence          => "correspondent_full_name_id_seq",
  },
  "correspondent",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "full_name",
  { data_type => "text", is_nullable => 0 },
  "last_seen",
  {
    data_type     => "timestamp",
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

=head2 C<correspondent_full_name_correspondent_full_name_idx>

=over 4

=item * L</correspondent>

=item * L</full_name>

=back

=cut

__PACKAGE__->add_unique_constraint(
  "correspondent_full_name_correspondent_full_name_idx",
  ["correspondent", "full_name"],
);

=head1 RELATIONS

=head2 correspondent

Type: belongs_to

Related object: L<Debbugs::DB::Result::Correspondent>

=cut

__PACKAGE__->belongs_to(
  "correspondent",
  "Debbugs::DB::Result::Correspondent",
  { id => "correspondent" },
  { is_deferrable => 0, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07042 @ 2014-11-30 21:56:51
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:rXiBbe/rMz4dOMgW5ZovWw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
