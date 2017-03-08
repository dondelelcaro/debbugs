use utf8;
package Debbugs::DB::Result::BugPackage;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Debbugs::DB::Result::BugPackage

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

=head1 TABLE: C<bug_package>

=cut

__PACKAGE__->table("bug_package");
__PACKAGE__->result_source_instance->view_definition(" SELECT b.bug,\n    b.bin_pkg AS pkg_id,\n    'binary'::text AS pkg_type,\n    bp.pkg AS package\n   FROM (bug_binpackage b\n     JOIN bin_pkg bp ON ((bp.id = b.bin_pkg)))\nUNION\n SELECT s.bug,\n    s.src_pkg AS pkg_id,\n    'source'::text AS pkg_type,\n    sp.pkg AS package\n   FROM (bug_srcpackage s\n     JOIN src_pkg sp ON ((sp.id = s.src_pkg)))");

=head1 ACCESSORS

=head2 bug

  data_type: 'integer'
  is_nullable: 1

=head2 pkg_id

  data_type: 'integer'
  is_nullable: 1

=head2 pkg_type

  data_type: 'text'
  is_nullable: 1

=head2 package

  data_type: 'text'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "bug",
  { data_type => "integer", is_nullable => 1 },
  "pkg_id",
  { data_type => "integer", is_nullable => 1 },
  "pkg_type",
  { data_type => "text", is_nullable => 1 },
  "package",
  { data_type => "text", is_nullable => 1 },
);


# Created by DBIx::Class::Schema::Loader v0.07046 @ 2017-03-04 10:59:03
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:+zeVIVZOYSZjTkD+1N2sdw

__PACKAGE__->result_source_instance->view_definition(<<EOF);
SELECT b.bug,b.bin_pkg,'binary',bp.pkg FROM bug_binpackage b JOIN bin_pkg bp ON bp.id=b.bin_pkg UNION
       SELECT s.bug,s.src_pkg,'source',sp.pkg FROM bug_srcpackage s JOIN src_pkg sp ON sp.id=s.src_pkg;
EOF


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
