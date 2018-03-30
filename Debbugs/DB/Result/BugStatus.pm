use utf8;
package Debbugs::DB::Result::BugStatus;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Debbugs::DB::Result::BugStatus

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
__PACKAGE__->table_class("DBIx::Class::ResultSource::View");

=head1 TABLE: C<bug_status>

=cut

__PACKAGE__->table("bug_status");
__PACKAGE__->result_source_instance->view_definition(" SELECT b.id,\n    b.id AS bug_num,\n    string_agg(t.tag, ','::text) AS tags,\n    b.subject,\n    ( SELECT s.severity\n           FROM severity s\n          WHERE (s.id = b.severity)) AS severity,\n    ( SELECT string_agg(package.package, ','::text ORDER BY package.package) AS string_agg\n           FROM ( SELECT bp.pkg AS package\n                   FROM (bug_binpackage bbp\n                     JOIN bin_pkg bp ON ((bbp.bin_pkg = bp.id)))\n                  WHERE (bbp.bug = b.id)\n                UNION\n                 SELECT concat('src:', sp.pkg) AS package\n                   FROM (bug_srcpackage bsp\n                     JOIN src_pkg sp ON ((bsp.src_pkg = sp.id)))\n                  WHERE (bsp.bug = b.id)) package) AS package,\n    b.submitter_full AS originator,\n    b.log_modified,\n    b.creation AS date,\n    b.last_modified,\n    string_agg((bb.blocks)::text, ' '::text ORDER BY bb.blocks) AS blocks,\n    string_agg((bbb.bug)::text, ' '::text ORDER BY bbb.bug) AS blockedby,\n    ( SELECT string_agg((bug.bug)::text, ' '::text ORDER BY bug.bug) AS string_agg\n           FROM ( SELECT b.id AS bug\n                UNION\n                 SELECT bm.merged AS bug\n                   FROM bug_merged bm\n                  WHERE (bm.bug = b.id)\n                UNION\n                 SELECT bm.bug\n                   FROM bug_merged bm\n                  WHERE (bm.merged = b.id)) bug) AS merged,\n    ( SELECT string_agg(bv.ver_string, ' '::text) AS string_agg\n           FROM bug_ver bv\n          WHERE ((bv.bug = b.id) AND (bv.found IS TRUE))) AS found_versions,\n    ( SELECT string_agg(bv.ver_string, ' '::text) AS string_agg\n           FROM bug_ver bv\n          WHERE ((bv.bug = b.id) AND (bv.found IS TRUE))) AS fixed_versions\n   FROM ((((bug b\n     LEFT JOIN bug_tag bt ON ((bt.bug = b.id)))\n     LEFT JOIN tag t ON ((bt.tag = t.id)))\n     LEFT JOIN bug_blocks bb ON ((bb.bug = b.id)))\n     LEFT JOIN bug_blocks bbb ON ((bbb.blocks = b.id)))\n  GROUP BY b.id");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_nullable: 1

=head2 bug_num

  data_type: 'integer'
  is_nullable: 1

=head2 tags

  data_type: 'text'
  is_nullable: 1

=head2 subject

  data_type: 'text'
  is_nullable: 1

=head2 severity

  data_type: 'text'
  is_nullable: 1

=head2 package

  data_type: 'text'
  is_nullable: 1

=head2 originator

  data_type: 'text'
  is_nullable: 1

=head2 log_modified

  data_type: 'timestamp with time zone'
  is_nullable: 1

=head2 date

  data_type: 'timestamp with time zone'
  is_nullable: 1

=head2 last_modified

  data_type: 'timestamp with time zone'
  is_nullable: 1

=head2 blocks

  data_type: 'text'
  is_nullable: 1

=head2 blockedby

  data_type: 'text'
  is_nullable: 1

=head2 merged

  data_type: 'text'
  is_nullable: 1

=head2 found_versions

  data_type: 'text'
  is_nullable: 1

=head2 fixed_versions

  data_type: 'text'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_nullable => 1 },
  "bug_num",
  { data_type => "integer", is_nullable => 1 },
  "tags",
  { data_type => "text", is_nullable => 1 },
  "subject",
  { data_type => "text", is_nullable => 1 },
  "severity",
  { data_type => "text", is_nullable => 1 },
  "package",
  { data_type => "text", is_nullable => 1 },
  "originator",
  { data_type => "text", is_nullable => 1 },
  "log_modified",
  { data_type => "timestamp with time zone", is_nullable => 1 },
  "date",
  { data_type => "timestamp with time zone", is_nullable => 1 },
  "last_modified",
  { data_type => "timestamp with time zone", is_nullable => 1 },
  "blocks",
  { data_type => "text", is_nullable => 1 },
  "blockedby",
  { data_type => "text", is_nullable => 1 },
  "merged",
  { data_type => "text", is_nullable => 1 },
  "found_versions",
  { data_type => "text", is_nullable => 1 },
  "fixed_versions",
  { data_type => "text", is_nullable => 1 },
);


# Created by DBIx::Class::Schema::Loader v0.07048 @ 2018-03-30 14:33:57
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Ao8wSsd8rmagJY0KoncYRg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
