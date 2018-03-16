use utf8;
package Debbugs::DB::Result::Suite;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Debbugs::DB::Result::Suite - Debian Release Suite (stable, testing, etc.)

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

=head1 TABLE: C<suite>

=cut

__PACKAGE__->table("suite");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'suite_id_seq'

Suite id

=head2 codename

  data_type: 'text'
  is_nullable: 0

Suite codename (sid, squeeze, etc.)

=head2 suite_name

  data_type: 'text'
  is_nullable: 1

Suite name (testing, stable, etc.)

=head2 version

  data_type: 'text'
  is_nullable: 1

Suite version; NULL if there is no appropriate version

=head2 active

  data_type: 'boolean'
  default_value: true
  is_nullable: 1

TRUE if the suite is still accepting uploads

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "suite_id_seq",
  },
  "codename",
  { data_type => "text", is_nullable => 0 },
  "suite_name",
  { data_type => "text", is_nullable => 1 },
  "version",
  { data_type => "text", is_nullable => 1 },
  "active",
  { data_type => "boolean", default_value => \"true", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<suite_idx_codename>

=over 4

=item * L</codename>

=back

=cut

__PACKAGE__->add_unique_constraint("suite_idx_codename", ["codename"]);

=head2 C<suite_idx_version>

=over 4

=item * L</version>

=back

=cut

__PACKAGE__->add_unique_constraint("suite_idx_version", ["version"]);

=head2 C<suite_suite_name_key>

=over 4

=item * L</suite_name>

=back

=cut

__PACKAGE__->add_unique_constraint("suite_suite_name_key", ["suite_name"]);

=head1 RELATIONS

=head2 bin_associations

Type: has_many

Related object: L<Debbugs::DB::Result::BinAssociation>

=cut

__PACKAGE__->has_many(
  "bin_associations",
  "Debbugs::DB::Result::BinAssociation",
  { "foreign.suite" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 bug_status_caches

Type: has_many

Related object: L<Debbugs::DB::Result::BugStatusCache>

=cut

__PACKAGE__->has_many(
  "bug_status_caches",
  "Debbugs::DB::Result::BugStatusCache",
  { "foreign.suite" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 src_associations

Type: has_many

Related object: L<Debbugs::DB::Result::SrcAssociation>

=cut

__PACKAGE__->has_many(
  "src_associations",
  "Debbugs::DB::Result::SrcAssociation",
  { "foreign.suite" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07045 @ 2016-11-24 08:52:49
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:nXoQCYZhM9cFgC1x+RY9rA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
