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


# Created by DBIx::Class::Schema::Loader v0.07042 @ 2014-11-30 21:56:51
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Ok2J+mjxvBcgdiqigiCBQA

__PACKAGE__->result_source_instance->view_definition(<<EOF);
SELECT b.bug,b.bin_pkg,'binary',bp.pkg FROM bug_binpackage b JOIN bin_pkg bp ON bp.id=b.bin_pkg UNION
       SELECT s.bug,s.src_pkg,'source',sp.pkg FROM bug_srcpackage s JOIN src_pkg sp ON sp.id=s.src_pkg;
EOF


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
