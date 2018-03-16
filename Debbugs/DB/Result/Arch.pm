use utf8;
package Debbugs::DB::Result::Arch;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Debbugs::DB::Result::Arch - Architectures

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

=head1 TABLE: C<arch>

=cut

__PACKAGE__->table("arch");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'arch_id_seq'

Architecture id

=head2 arch

  data_type: 'text'
  is_nullable: 0

Architecture name

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "arch_id_seq",
  },
  "arch",
  { data_type => "text", is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<arch_arch_key>

=over 4

=item * L</arch>

=back

=cut

__PACKAGE__->add_unique_constraint("arch_arch_key", ["arch"]);

=head1 RELATIONS

=head2 bin_vers

Type: has_many

Related object: L<Debbugs::DB::Result::BinVer>

=cut

__PACKAGE__->has_many(
  "bin_vers",
  "Debbugs::DB::Result::BinVer",
  { "foreign.arch" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 bug_status_caches

Type: has_many

Related object: L<Debbugs::DB::Result::BugStatusCache>

=cut

__PACKAGE__->has_many(
  "bug_status_caches",
  "Debbugs::DB::Result::BugStatusCache",
  { "foreign.arch" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07042 @ 2014-11-30 21:56:51
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:9pDiZg68Odz66DpCB9GpsA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
