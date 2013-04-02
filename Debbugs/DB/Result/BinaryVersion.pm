use utf8;
package Debbugs::DB::Result::BinaryVersion;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Debbugs::DB::Result::BinaryVersion

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

=head1 TABLE: C<binary_versions>

=cut

__PACKAGE__->table("binary_versions");

=head1 ACCESSORS

=head2 src_pkg

  data_type: 'text'
  is_nullable: 1

=head2 src_ver

  data_type: 'debversion'
  is_nullable: 1

=head2 bin_pkg

  data_type: 'text'
  is_nullable: 1

=head2 arch

  data_type: 'text'
  is_nullable: 1

=head2 bin_ver

  data_type: 'debversion'
  is_nullable: 1

=head2 src_ver_based_on

  data_type: 'debversion'
  is_nullable: 1

=head2 src_pkg_based_on

  data_type: 'text'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "src_pkg",
  { data_type => "text", is_nullable => 1 },
  "src_ver",
  { data_type => "debversion", is_nullable => 1 },
  "bin_pkg",
  { data_type => "text", is_nullable => 1 },
  "arch",
  { data_type => "text", is_nullable => 1 },
  "bin_ver",
  { data_type => "debversion", is_nullable => 1 },
  "src_ver_based_on",
  { data_type => "debversion", is_nullable => 1 },
  "src_pkg_based_on",
  { data_type => "text", is_nullable => 1 },
);


# Created by DBIx::Class::Schema::Loader v0.07025 @ 2013-03-27 18:54:20
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:PiJglTBqLYRIi63gvGWIDQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
