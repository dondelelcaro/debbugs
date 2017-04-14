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

=head2 correspondent

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

Correspondent ID (matches correspondent)

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


# Created by DBIx::Class::Schema::Loader v0.07046 @ 2017-03-04 10:59:03
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:2Ac8mrDV2IsE/11YsYoqQQ

sub sqlt_deploy_hook {
    my ($self, $sqlt_table) = @_;
    for my $idx (qw(correspondent message)) {
	$sqlt_table->add_index(name => 'message_correspondent_idx'.$idx,
			       fields => [$idx]);
    }
}

1;
