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

=back

=cut

__PACKAGE__->load_components("InflateColumn::DateTime");

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


# Created by DBIx::Class::Schema::Loader v0.07025 @ 2013-03-27 18:54:20
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:593NXq7J5AFjjfFjMLXIvw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
