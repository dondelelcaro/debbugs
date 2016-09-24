use utf8;
package Debbugs::DB::Result::BugStatusCache;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Debbugs::DB::Result::BugStatusCache - Bug Status Cache

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

=head1 TABLE: C<bug_status_cache>

=cut

__PACKAGE__->table("bug_status_cache");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'bug_status_cache_id_seq'

Bug status cache entry id

=head2 bug

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

Bug number (matches bug)

=head2 suite

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

Suite id (matches suite)

=head2 arch

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

Architecture id (matches arch)

=head2 status

  data_type: 'enum'
  extra: {custom_type_name => "bug_status_type",list => ["pending","forwarded","pending-fixed","fixed","absent","done"]}
  is_nullable: 0

Status (bug status)

=head2 modified

  data_type: 'timestamp with time zone'
  default_value: current_timestamp
  is_nullable: 0
  original: {default_value => \"now()"}

Time that this status was last modified

=head2 asof

  data_type: 'timestamp with time zone'
  default_value: current_timestamp
  is_nullable: 0
  original: {default_value => \"now()"}

Time that this status was last calculated

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "bug_status_cache_id_seq",
  },
  "bug",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "suite",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "arch",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "status",
  {
    data_type => "enum",
    extra => {
      custom_type_name => "bug_status_type",
      list => [
        "pending",
        "forwarded",
        "pending-fixed",
        "fixed",
        "absent",
        "done",
      ],
    },
    is_nullable => 0,
  },
  "modified",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
  "asof",
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

=head2 C<bug_status_cache_bug_suite_arch_idx>

=over 4

=item * L</bug>

=item * L</suite>

=item * L</arch>

=back

=cut

__PACKAGE__->add_unique_constraint(
  "bug_status_cache_bug_suite_arch_idx",
  ["bug", "suite", "arch"],
);

=head1 RELATIONS

=head2 arch

Type: belongs_to

Related object: L<Debbugs::DB::Result::Arch>

=cut

__PACKAGE__->belongs_to(
  "arch",
  "Debbugs::DB::Result::Arch",
  { id => "arch" },
  {
    is_deferrable => 0,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);

=head2 bug

Type: belongs_to

Related object: L<Debbugs::DB::Result::Bug>

=cut

__PACKAGE__->belongs_to(
  "bug",
  "Debbugs::DB::Result::Bug",
  { id => "bug" },
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
  {
    is_deferrable => 0,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);


# Created by DBIx::Class::Schema::Loader v0.07045 @ 2016-09-24 14:51:07
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:jrPFpLs6vLgKWMSLyJAkxA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
