use utf8;
package Debbugs::DB::Result::BugBlock;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Debbugs::DB::Result::BugBlock - Bugs which block other bugs

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

=head1 TABLE: C<bug_blocks>

=cut

__PACKAGE__->table("bug_blocks");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'bug_blocks_id_seq'

=head2 bug

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

Bug number

=head2 blocks

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

Bug number which is blocked by bug

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "bug_blocks_id_seq",
  },
  "bug",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "blocks",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<bug_blocks_bug_id_blocks_idx>

=over 4

=item * L</bug>

=item * L</blocks>

=back

=cut

__PACKAGE__->add_unique_constraint("bug_blocks_bug_id_blocks_idx", ["bug", "blocks"]);

=head1 RELATIONS

=head2 block

Type: belongs_to

Related object: L<Debbugs::DB::Result::Bug>

=cut

__PACKAGE__->belongs_to(
  "block",
  "Debbugs::DB::Result::Bug",
  { id => "blocks" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);

=head2 bug

Type: belongs_to

Related object: L<Debbugs::DB::Result::Bug>

=cut

__PACKAGE__->belongs_to(
  "bug",
  "Debbugs::DB::Result::Bug",
  { id => "bug" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader v0.07042 @ 2014-11-30 21:56:51
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Rkt0XlA4r2YFX0KnUZmS6A


sub sqlt_deploy_hook {
    my ($self, $sqlt_table) = @_;
    for my $idx (qw(bug blocks)) {
	$sqlt_table->add_index(name => 'bug_blocks_'.$idx.'_idx',
			       fields => [$idx]);
    }
}

1;
