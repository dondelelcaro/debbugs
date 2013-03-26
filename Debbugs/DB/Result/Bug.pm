use utf8;
package Debbugs::DB::Result::Bug;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Debbugs::DB::Result::Bug - Bugs

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

=head1 TABLE: C<bug>

=cut

__PACKAGE__->table("bug");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_nullable: 0

Bug number

=head2 creation

  data_type: 'timestamp with time zone'
  default_value: current_timestamp
  is_nullable: 0
  original: {default_value => \"now()"}

Time bug created

=head2 log_modified

  data_type: 'timestamp with time zone'
  default_value: current_timestamp
  is_nullable: 0
  original: {default_value => \"now()"}

Time bug log was last modified

=head2 last_modified

  data_type: 'timestamp with time zone'
  default_value: current_timestamp
  is_nullable: 0
  original: {default_value => \"now()"}

Time bug status was last modified

=head2 archived

  data_type: 'boolean'
  default_value: false
  is_nullable: 0

True if bug has been archived

=head2 unarchived

  data_type: 'timestamp with time zone'
  is_nullable: 1

Time bug was last unarchived; null if bug has never been unarchived

=head2 forwarded

  data_type: 'text'
  default_value: (empty string)
  is_nullable: 0

Where bug has been forwarded to; empty if it has not been forwarded

=head2 summary

  data_type: 'text'
  default_value: (empty string)
  is_nullable: 0

Summary of the bug; empty if it has no summary

=head2 outlook

  data_type: 'text'
  default_value: (empty string)
  is_nullable: 0

Outlook of the bug; empty if it has no outlook

=head2 subject

  data_type: 'text'
  is_nullable: 0

Subject of the bug

=head2 done

  data_type: 'text'
  default_value: (empty string)
  is_nullable: 0

Individual who did the -done; empty if it has never been -done

=head2 owner

  data_type: 'text'
  default_value: (empty string)
  is_nullable: 0

Individual who owns this bug; empty if no one owns it

=head2 submitter

  data_type: 'text'
  default_value: (empty string)
  is_nullable: 0

Individual who submitted this bug; empty if there is no submitter

=head2 unknown_packages

  data_type: 'text'
  default_value: (empty string)
  is_nullable: 0

Package name if the package is not known

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_nullable => 0 },
  "creation",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
  "log_modified",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
  "last_modified",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
  "archived",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "unarchived",
  { data_type => "timestamp with time zone", is_nullable => 1 },
  "forwarded",
  { data_type => "text", default_value => "", is_nullable => 0 },
  "summary",
  { data_type => "text", default_value => "", is_nullable => 0 },
  "outlook",
  { data_type => "text", default_value => "", is_nullable => 0 },
  "subject",
  { data_type => "text", is_nullable => 0 },
  "done",
  { data_type => "text", default_value => "", is_nullable => 0 },
  "owner",
  { data_type => "text", default_value => "", is_nullable => 0 },
  "submitter",
  { data_type => "text", default_value => "", is_nullable => 0 },
  "unknown_packages",
  { data_type => "text", default_value => "", is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 bug_binpackages

Type: has_many

Related object: L<Debbugs::DB::Result::BugBinpackage>

=cut

__PACKAGE__->has_many(
  "bug_binpackages",
  "Debbugs::DB::Result::BugBinpackage",
  { "foreign.bug" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 bug_blocks_blocks

Type: has_many

Related object: L<Debbugs::DB::Result::BugBlock>

=cut

__PACKAGE__->has_many(
  "bug_blocks_blocks",
  "Debbugs::DB::Result::BugBlock",
  { "foreign.blocks" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 bug_blocks_bugs

Type: has_many

Related object: L<Debbugs::DB::Result::BugBlock>

=cut

__PACKAGE__->has_many(
  "bug_blocks_bugs",
  "Debbugs::DB::Result::BugBlock",
  { "foreign.bug" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 bug_merged_bugs

Type: has_many

Related object: L<Debbugs::DB::Result::BugMerged>

=cut

__PACKAGE__->has_many(
  "bug_merged_bugs",
  "Debbugs::DB::Result::BugMerged",
  { "foreign.bug" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 bug_messages

Type: has_many

Related object: L<Debbugs::DB::Result::BugMessage>

=cut

__PACKAGE__->has_many(
  "bug_messages",
  "Debbugs::DB::Result::BugMessage",
  { "foreign.bug" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 bug_severity

Type: might_have

Related object: L<Debbugs::DB::Result::BugSeverity>

=cut

__PACKAGE__->might_have(
  "bug_severity",
  "Debbugs::DB::Result::BugSeverity",
  { "foreign.bug" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 bug_srcpackages

Type: has_many

Related object: L<Debbugs::DB::Result::BugSrcpackage>

=cut

__PACKAGE__->has_many(
  "bug_srcpackages",
  "Debbugs::DB::Result::BugSrcpackage",
  { "foreign.bug" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 bug_submitters

Type: has_many

Related object: L<Debbugs::DB::Result::BugSubmitter>

=cut

__PACKAGE__->has_many(
  "bug_submitters",
  "Debbugs::DB::Result::BugSubmitter",
  { "foreign.bug" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 bug_tags

Type: has_many

Related object: L<Debbugs::DB::Result::BugTag>

=cut

__PACKAGE__->has_many(
  "bug_tags",
  "Debbugs::DB::Result::BugTag",
  { "foreign.bug" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 bug_vers

Type: has_many

Related object: L<Debbugs::DB::Result::BugVer>

=cut

__PACKAGE__->has_many(
  "bug_vers",
  "Debbugs::DB::Result::BugVer",
  { "foreign.bug" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 bugs_done_by

Type: has_many

Related object: L<Debbugs::DB::Result::BugDoneBy>

=cut

__PACKAGE__->has_many(
  "bugs_done_by",
  "Debbugs::DB::Result::BugDoneBy",
  { "foreign.bug" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 bugs_merged_merged

Type: has_many

Related object: L<Debbugs::DB::Result::BugMerged>

=cut

__PACKAGE__->has_many(
  "bugs_merged_merged",
  "Debbugs::DB::Result::BugMerged",
  { "foreign.merged" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07025 @ 2013-03-25 18:43:53
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:cPIz8V6KUWZip+5Dvi7+4Q


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
