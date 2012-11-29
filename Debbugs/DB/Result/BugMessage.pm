use utf8;
package Debbugs::DB::Result::BugMessage;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Debbugs::DB::Result::BugMessage

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

=head1 TABLE: C<bug_message>

=cut

__PACKAGE__->table("bug_message");

=head1 ACCESSORS

=head2 bug

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 message

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 message_number

  data_type: 'integer'
  is_nullable: 0

=head2 bug_log_offset

  data_type: 'integer'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "bug",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "message",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "message_number",
  { data_type => "integer", is_nullable => 0 },
  "bug_log_offset",
  { data_type => "integer", is_nullable => 1 },
);

=head1 RELATIONS

=head2 bug

Type: belongs_to

Related object: L<Debbugs::DB::Result::Bug>

=cut

__PACKAGE__->belongs_to(
  "bug",
  "Debbugs::DB::Result::Bug",
  { id => "bug" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 message

Type: belongs_to

Related object: L<Debbugs::DB::Result::Message>

=cut

__PACKAGE__->belongs_to(
  "message",
  "Debbugs::DB::Result::Message",
  { id => "message" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07025 @ 2012-11-29 15:37:55
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:7CxTYa/jUyoOVan9Sj9MZQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
