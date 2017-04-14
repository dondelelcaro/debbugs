use utf8;
package Debbugs::DB::Result::BinVer;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Debbugs::DB::Result::BinVer - Binary versions

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

=head1 TABLE: C<bin_ver>

=cut

__PACKAGE__->table("bin_ver");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'bin_ver_id_seq'

Binary version id

=head2 bin_pkg

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

Binary package id (matches bin_pkg)

=head2 src_ver

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

Source version (matchines src_ver)

=head2 arch

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

Architecture id (matches arch)

=head2 ver

  data_type: 'debversion'
  is_nullable: 0

Binary version

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "bin_ver_id_seq",
  },
  "bin_pkg",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "src_ver",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "arch",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "ver",
  { data_type => "debversion", is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<bin_ver_bin_pkg_id_arch_idx>

=over 4

=item * L</bin_pkg>

=item * L</arch>

=item * L</ver>

=back

=cut

__PACKAGE__->add_unique_constraint("bin_ver_bin_pkg_id_arch_idx", ["bin_pkg", "arch", "ver"]);

=head1 RELATIONS

=head2 arch

Type: belongs_to

Related object: L<Debbugs::DB::Result::Arch>

=cut

__PACKAGE__->belongs_to(
  "arch",
  "Debbugs::DB::Result::Arch",
  { id => "arch" },
  { is_deferrable => 0, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 bin_associations

Type: has_many

Related object: L<Debbugs::DB::Result::BinAssociation>

=cut

__PACKAGE__->has_many(
  "bin_associations",
  "Debbugs::DB::Result::BinAssociation",
  { "foreign.bin" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 bin_pkg

Type: belongs_to

Related object: L<Debbugs::DB::Result::BinPkg>

=cut

__PACKAGE__->belongs_to(
  "bin_pkg",
  "Debbugs::DB::Result::BinPkg",
  { id => "bin_pkg" },
  { is_deferrable => 0, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 src_ver

Type: belongs_to

Related object: L<Debbugs::DB::Result::SrcVer>

=cut

__PACKAGE__->belongs_to(
  "src_ver",
  "Debbugs::DB::Result::SrcVer",
  { id => "src_ver" },
  { is_deferrable => 0, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07045 @ 2016-11-24 09:08:27
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:DzTzZbPkilT8WMhXoZv9xw


sub sqlt_deploy_hook {
    my ($self, $sqlt_table) = @_;
    for my $idx (qw(var bin_pkg src_ver)) {
	$sqlt_table->add_index(name => 'bin_ver_'.$idx.'_id_idx',
			       fields => [$idx]);
    }
    $sqlt_table->add_index(name => 'bin_ver_src_ver_id_arch_idx',
			   fields => [qw(src_ver arch)]
			  );
}

1;
