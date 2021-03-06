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

=item * L<DBIx::Class::TimeStamp>

=back

=cut

__PACKAGE__->load_components("InflateColumn::DateTime", "TimeStamp");
__PACKAGE__->table_class("DBIx::Class::ResultSource::View");

=head1 TABLE: C<binary_versions>

=cut

__PACKAGE__->table("binary_versions");
__PACKAGE__->result_source_instance->view_definition(" SELECT sp.pkg AS src_pkg,\n    sv.ver AS src_ver,\n    bp.pkg AS bin_pkg,\n    a.arch,\n    b.ver AS bin_ver,\n    svb.ver AS src_ver_based_on,\n    spb.pkg AS src_pkg_based_on\n   FROM ((((((bin_ver b\n     JOIN arch a ON ((b.arch = a.id)))\n     JOIN bin_pkg bp ON ((b.bin_pkg = bp.id)))\n     JOIN src_ver sv ON ((b.src_ver = sv.id)))\n     JOIN src_pkg sp ON ((sv.src_pkg = sp.id)))\n     LEFT JOIN src_ver svb ON ((sv.based_on = svb.id)))\n     LEFT JOIN src_pkg spb ON ((spb.id = svb.src_pkg)))");

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


# Created by DBIx::Class::Schema::Loader v0.07046 @ 2017-03-04 10:59:03
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:0MeJnGxBc8gdEoPE6Sn6Sw

__PACKAGE__->result_source_instance->view_definition(<<EOF);
SELECT sp.pkg AS src_pkg, sv.ver AS src_ver, bp.pkg AS bin_pkg, a.arch AS arch, b.ver AS bin_ver,
svb.ver AS src_ver_based_on, spb.pkg AS src_pkg_based_on
FROM bin_ver b JOIN arch a ON b.arch = a.id
	              JOIN bin_pkg bp ON b.bin_pkg  = bp.id
               JOIN src_ver sv ON b.src_ver  = sv.id
               JOIN src_pkg sp ON sv.src_pkg = sp.id
               LEFT OUTER JOIN src_ver svb ON sv.based_on = svb.id
               LEFT OUTER JOIN src_pkg spb ON spb.id = svb.src_pkg;
EOF

# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
