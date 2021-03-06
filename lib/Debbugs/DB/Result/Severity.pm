use utf8;
package Debbugs::DB::Result::Severity;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Debbugs::DB::Result::Severity - Bug severity

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

=head1 TABLE: C<severity>

=cut

__PACKAGE__->table("severity");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'severity_id_seq'

Severity id

=head2 severity

  data_type: 'text'
  is_nullable: 0

Severity name

=head2 ordering

  data_type: 'integer'
  default_value: 5
  is_nullable: 0

Severity ordering (more severe severities have higher numbers)

=head2 strong

  data_type: 'boolean'
  default_value: false
  is_nullable: 1

True if severity is a strong severity

=head2 obsolete

  data_type: 'boolean'
  default_value: false
  is_nullable: 1

Whether a severity level is obsolete (should not be set on new bugs)

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "severity_id_seq",
  },
  "severity",
  { data_type => "text", is_nullable => 0 },
  "ordering",
  { data_type => "integer", default_value => 5, is_nullable => 0 },
  "strong",
  { data_type => "boolean", default_value => \"false", is_nullable => 1 },
  "obsolete",
  { data_type => "boolean", default_value => \"false", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<severity_severity_idx>

=over 4

=item * L</severity>

=back

=cut

__PACKAGE__->add_unique_constraint("severity_severity_idx", ["severity"]);

=head1 RELATIONS

=head2 bugs

Type: has_many

Related object: L<Debbugs::DB::Result::Bug>

=cut

__PACKAGE__->has_many(
  "bugs",
  "Debbugs::DB::Result::Bug",
  { "foreign.severity" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07042 @ 2014-11-30 21:56:51
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:nI4ZqWa6IW7LgWuG7S1Gog

sub sqlt_deploy_hook {
    my ($self, $sqlt_table) = @_;
    $sqlt_table->add_index(name => 'severity_ordering_idx',
			   fields => [qw(ordering)],
			  );
}

1;
