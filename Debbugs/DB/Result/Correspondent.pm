use utf8;
package Debbugs::DB::Result::Correspondent;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Debbugs::DB::Result::Correspondent - Individual who has corresponded with the BTS

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

=head1 TABLE: C<correspondent>

=cut

__PACKAGE__->table("correspondent");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'correspondent_id_seq'

Correspondent ID

=head2 addr

  data_type: 'text'
  is_nullable: 0

Correspondent address

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "correspondent_id_seq",
  },
  "addr",
  { data_type => "text", is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<correspondent_addr_idx>

=over 4

=item * L</addr>

=back

=cut

__PACKAGE__->add_unique_constraint("correspondent_addr_idx", ["addr"]);

=head1 RELATIONS

=head2 bug_owners

Type: has_many

Related object: L<Debbugs::DB::Result::Bug>

=cut

__PACKAGE__->has_many(
  "bug_owners",
  "Debbugs::DB::Result::Bug",
  { "foreign.owner" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 bug_submitters

Type: has_many

Related object: L<Debbugs::DB::Result::Bug>

=cut

__PACKAGE__->has_many(
  "bug_submitters",
  "Debbugs::DB::Result::Bug",
  { "foreign.submitter" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 bugs_done

Type: has_many

Related object: L<Debbugs::DB::Result::Bug>

=cut

__PACKAGE__->has_many(
  "bugs_done",
  "Debbugs::DB::Result::Bug",
  { "foreign.done" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 correspondent_full_names

Type: has_many

Related object: L<Debbugs::DB::Result::CorrespondentFullName>

=cut

__PACKAGE__->has_many(
  "correspondent_full_names",
  "Debbugs::DB::Result::CorrespondentFullName",
  { "foreign.correspondent" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 maintainers

Type: has_many

Related object: L<Debbugs::DB::Result::Maintainer>

=cut

__PACKAGE__->has_many(
  "maintainers",
  "Debbugs::DB::Result::Maintainer",
  { "foreign.correspondent" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 message_correspondents

Type: has_many

Related object: L<Debbugs::DB::Result::MessageCorrespondent>

=cut

__PACKAGE__->has_many(
  "message_correspondents",
  "Debbugs::DB::Result::MessageCorrespondent",
  { "foreign.correspondent" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07042 @ 2014-11-30 21:56:51
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:lFyRZdUZXsbDv0Xc6c4cAQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
