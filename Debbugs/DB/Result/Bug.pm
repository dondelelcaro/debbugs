use utf8;
package Debbugs::DB::Result::Bug;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Debbugs::DB::Result::Bug

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

=head2 creation

  data_type: 'timestamp with time zone'
  default_value: current_timestamp
  is_nullable: 0
  original: {default_value => \"now()"}

=head2 log_modified

  data_type: 'timestamp with time zone'
  default_value: current_timestamp
  is_nullable: 0
  original: {default_value => \"now()"}

=head2 last_modified

  data_type: 'timestamp with time zone'
  default_value: current_timestamp
  is_nullable: 0
  original: {default_value => \"now()"}

=head2 archived

  data_type: 'boolean'
  default_value: false
  is_nullable: 0

=head2 unarchived

  data_type: 'timestamp with time zone'
  is_nullable: 1

=head2 forwarded

  data_type: 'text'
  default_value: (empty string)
  is_nullable: 0

=head2 summary

  data_type: 'text'
  default_value: (empty string)
  is_nullable: 0

=head2 outlook

  data_type: 'text'
  default_value: (empty string)
  is_nullable: 0

=head2 subject

  data_type: 'text'
  is_nullable: 0

=head2 done

  data_type: 'text'
  default_value: (empty string)
  is_nullable: 0

=head2 owner

  data_type: 'text'
  default_value: (empty string)
  is_nullable: 0

=head2 unknown_packages

  data_type: 'text'
  default_value: (empty string)
  is_nullable: 0

=head2 severity

  data_type: 'enum'
  default_value: 'normal'
  extra: {custom_type_name => "bug_severity",list => ["wishlist","minor","normal","important","serious","grave","critical"]}
  is_nullable: 1

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
  "unknown_packages",
  { data_type => "text", default_value => "", is_nullable => 0 },
  "severity",
  {
    data_type => "enum",
    default_value => "normal",
    extra => {
      custom_type_name => "bug_severity",
      list => [
        "wishlist",
        "minor",
        "normal",
        "important",
        "serious",
        "grave",
        "critical",
      ],
    },
    is_nullable => 1,
  },
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
  { "foreign.bug_id" => "self.id" },
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
  { "foreign.bug_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 bug_merged_bugs

Type: has_many

Related object: L<Debbugs::DB::Result::BugMerged>

=cut

__PACKAGE__->has_many(
  "bug_merged_bugs",
  "Debbugs::DB::Result::BugMerged",
  { "foreign.bug_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 bug_srcpackages

Type: has_many

Related object: L<Debbugs::DB::Result::BugSrcpackage>

=cut

__PACKAGE__->has_many(
  "bug_srcpackages",
  "Debbugs::DB::Result::BugSrcpackage",
  { "foreign.bug_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 bug_tags

Type: has_many

Related object: L<Debbugs::DB::Result::BugTag>

=cut

__PACKAGE__->has_many(
  "bug_tags",
  "Debbugs::DB::Result::BugTag",
  { "foreign.bug_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 bug_vers

Type: has_many

Related object: L<Debbugs::DB::Result::BugVer>

=cut

__PACKAGE__->has_many(
  "bug_vers",
  "Debbugs::DB::Result::BugVer",
  { "foreign.bug_id" => "self.id" },
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


# Created by DBIx::Class::Schema::Loader v0.07025 @ 2012-07-17 21:09:18
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:k+98VF0kOIp6OReqNNVXDg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
