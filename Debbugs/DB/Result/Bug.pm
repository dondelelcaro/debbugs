use utf8;
package Debbugs::DB::Result::Bug;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Debbugs::DB::Result::Bug - Bugs

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

=head1 TABLE: C<bug>

=cut

__PACKAGE__->table("bug");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_nullable: 0

Bug number

=head2 creation

  data_type: 'timestamp with time zone'
  default_value: current_timestamp
  is_nullable: 0
  original: {default_value => \"now()"}

Time bug created

=head2 log_modified

  data_type: 'timestamp with time zone'
  default_value: current_timestamp
  is_nullable: 0
  original: {default_value => \"now()"}

Time bug log was last modified

=head2 last_modified

  data_type: 'timestamp with time zone'
  default_value: current_timestamp
  is_nullable: 0
  original: {default_value => \"now()"}

Time bug status was last modified

=head2 archived

  data_type: 'boolean'
  default_value: false
  is_nullable: 0

True if bug has been archived

=head2 unarchived

  data_type: 'timestamp with time zone'
  is_nullable: 1

Time bug was last unarchived; null if bug has never been unarchived

=head2 forwarded

  data_type: 'text'
  default_value: (empty string)
  is_nullable: 0

Where bug has been forwarded to; empty if it has not been forwarded

=head2 summary

  data_type: 'text'
  default_value: (empty string)
  is_nullable: 0

Summary of the bug; empty if it has no summary

=head2 outlook

  data_type: 'text'
  default_value: (empty string)
  is_nullable: 0

Outlook of the bug; empty if it has no outlook

=head2 subject

  data_type: 'text'
  is_nullable: 0

Subject of the bug

=head2 severity

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 done

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

Individual who did the -done; empty if it has never been -done

=head2 done_full

  data_type: 'text'
  default_value: (empty string)
  is_nullable: 0

=head2 owner

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

Individual who owns this bug; empty if no one owns it

=head2 owner_full

  data_type: 'text'
  default_value: (empty string)
  is_nullable: 0

=head2 submitter

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

Individual who submitted this bug; empty if there is no submitter

=head2 submitter_full

  data_type: 'text'
  default_value: (empty string)
  is_nullable: 0

=head2 unknown_packages

  data_type: 'text'
  default_value: (empty string)
  is_nullable: 0

Package name if the package is not known

=head2 unknown_affects

  data_type: 'text'
  default_value: (empty string)
  is_nullable: 0

Package name if the affected package is not known

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_nullable => 0 },
  "creation",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
  "log_modified",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
  "last_modified",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
  "archived",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "unarchived",
  { data_type => "timestamp with time zone", is_nullable => 1 },
  "forwarded",
  { data_type => "text", default_value => "", is_nullable => 0 },
  "summary",
  { data_type => "text", default_value => "", is_nullable => 0 },
  "outlook",
  { data_type => "text", default_value => "", is_nullable => 0 },
  "subject",
  { data_type => "text", is_nullable => 0 },
  "severity",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "done",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "done_full",
  { data_type => "text", default_value => "", is_nullable => 0 },
  "owner",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "owner_full",
  { data_type => "text", default_value => "", is_nullable => 0 },
  "submitter",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "submitter_full",
  { data_type => "text", default_value => "", is_nullable => 0 },
  "unknown_packages",
  { data_type => "text", default_value => "", is_nullable => 0 },
  "unknown_affects",
  { data_type => "text", default_value => "", is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 bug_affects_binpackages

Type: has_many

Related object: L<Debbugs::DB::Result::BugAffectsBinpackage>

=cut

__PACKAGE__->has_many(
  "bug_affects_binpackages",
  "Debbugs::DB::Result::BugAffectsBinpackage",
  { "foreign.bug" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 bug_affects_srcpackages

Type: has_many

Related object: L<Debbugs::DB::Result::BugAffectsSrcpackage>

=cut

__PACKAGE__->has_many(
  "bug_affects_srcpackages",
  "Debbugs::DB::Result::BugAffectsSrcpackage",
  { "foreign.bug" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 bug_binpackages

Type: has_many

Related object: L<Debbugs::DB::Result::BugBinpackage>

=cut

__PACKAGE__->has_many(
  "bug_binpackages",
  "Debbugs::DB::Result::BugBinpackage",
  { "foreign.bug" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 bug_blocks_blocks

Type: has_many

Related object: L<Debbugs::DB::Result::BugBlock>

=cut

__PACKAGE__->has_many(
  "bug_blocks_blocks",
  "Debbugs::DB::Result::BugBlock",
  { "foreign.blocks" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 bug_blocks_bugs

Type: has_many

Related object: L<Debbugs::DB::Result::BugBlock>

=cut

__PACKAGE__->has_many(
  "bug_blocks_bugs",
  "Debbugs::DB::Result::BugBlock",
  { "foreign.bug" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 bug_merged_bugs

Type: has_many

Related object: L<Debbugs::DB::Result::BugMerged>

=cut

__PACKAGE__->has_many(
  "bug_merged_bugs",
  "Debbugs::DB::Result::BugMerged",
  { "foreign.bug" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 bug_mergeds_merged

Type: has_many

Related object: L<Debbugs::DB::Result::BugMerged>

=cut

__PACKAGE__->has_many(
  "bug_mergeds_merged",
  "Debbugs::DB::Result::BugMerged",
  { "foreign.merged" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 bug_messages

Type: has_many

Related object: L<Debbugs::DB::Result::BugMessage>

=cut

__PACKAGE__->has_many(
  "bug_messages",
  "Debbugs::DB::Result::BugMessage",
  { "foreign.bug" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 bug_srcpackages

Type: has_many

Related object: L<Debbugs::DB::Result::BugSrcpackage>

=cut

__PACKAGE__->has_many(
  "bug_srcpackages",
  "Debbugs::DB::Result::BugSrcpackage",
  { "foreign.bug" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 bug_status_caches

Type: has_many

Related object: L<Debbugs::DB::Result::BugStatusCache>

=cut

__PACKAGE__->has_many(
  "bug_status_caches",
  "Debbugs::DB::Result::BugStatusCache",
  { "foreign.bug" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 bug_tags

Type: has_many

Related object: L<Debbugs::DB::Result::BugTag>

=cut

__PACKAGE__->has_many(
  "bug_tags",
  "Debbugs::DB::Result::BugTag",
  { "foreign.bug" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 bug_user_tags

Type: has_many

Related object: L<Debbugs::DB::Result::BugUserTag>

=cut

__PACKAGE__->has_many(
  "bug_user_tags",
  "Debbugs::DB::Result::BugUserTag",
  { "foreign.bug" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 bug_vers

Type: has_many

Related object: L<Debbugs::DB::Result::BugVer>

=cut

__PACKAGE__->has_many(
  "bug_vers",
  "Debbugs::DB::Result::BugVer",
  { "foreign.bug" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 done

Type: belongs_to

Related object: L<Debbugs::DB::Result::Correspondent>

=cut

__PACKAGE__->belongs_to(
  "done",
  "Debbugs::DB::Result::Correspondent",
  { id => "done" },
  {
    is_deferrable => 0,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);

=head2 owner

Type: belongs_to

Related object: L<Debbugs::DB::Result::Correspondent>

=cut

__PACKAGE__->belongs_to(
  "owner",
  "Debbugs::DB::Result::Correspondent",
  { id => "owner" },
  {
    is_deferrable => 0,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);

=head2 severity

Type: belongs_to

Related object: L<Debbugs::DB::Result::Severity>

=cut

__PACKAGE__->belongs_to(
  "severity",
  "Debbugs::DB::Result::Severity",
  { id => "severity" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);

=head2 submitter

Type: belongs_to

Related object: L<Debbugs::DB::Result::Correspondent>

=cut

__PACKAGE__->belongs_to(
  "submitter",
  "Debbugs::DB::Result::Correspondent",
  { id => "submitter" },
  {
    is_deferrable => 0,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);


# Created by DBIx::Class::Schema::Loader v0.07048 @ 2018-04-11 13:06:55
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:qxkLXbv8JGoV9reebbOUEw

use Carp;
use List::AllUtils qw(uniq);

__PACKAGE__->many_to_many(tags => 'bug_tags','tag');
__PACKAGE__->many_to_many(user_tags => 'bug_user_tags','user_tag');
__PACKAGE__->many_to_many(srcpackages => 'bug_srcpackages','src_pkg');
__PACKAGE__->many_to_many(binpackages => 'bug_binpackages','bin_pkg');
__PACKAGE__->many_to_many(affects_binpackages => 'bug_affects_binpackages','bin_pkg');
__PACKAGE__->many_to_many(affects_srcpackages => 'bug_affects_srcpackages','src_pkg');
__PACKAGE__->many_to_many(messages => 'bug_messages','message');

sub sqlt_deploy_hook {
    my ($self, $sqlt_table) = @_;
    # CREATE INDEX bug_idx_owner ON bug(owner);
    # CREATE INDEX bug_idx_submitter ON bug(submitter);
    # CREATE INDEX bug_idx_done ON bug(done);
    # CREATE INDEX bug_idx_forwarded ON bug(forwarded);
    # CREATE INDEX bug_idx_last_modified ON bug(last_modified);
    # CREATE INDEX bug_idx_severity ON bug(severity);
    # CREATE INDEX bug_idx_creation ON bug(creation);
    # CREATE INDEX bug_idx_log_modified ON bug(log_modified);
    for my $idx (qw(owner submitter done forwarded last_modified),
		 qw(severity creation log_modified),
		) {
	$sqlt_table->add_index(name => 'bug_idx'.$idx,
			       fields => [$idx]);
    }
}

=head1 Utility Functions

=cut

=head2 set_related_packages

 $b->set_related_packages($relationship,
			  \@packages,
			  $package_cache ,
			 );

Set bug-related packages.

=cut

sub set_related_packages {
    my ($self,$relationship,$pkgs,$pkg_cache) = @_;

    my @unset_packages;
    my @pkg_ids;
    if ($relationship =~ /binpackages/) {
        for my $pkg (@{$pkgs}) {
	    my $pkg_id =
              $self->result_source->schema->resultset('BinPkg')->
              get_bin_pkg_id($pkg);
	    if (not defined $pkg_id) {
		push @unset_packages,$pkg;
	    } else {
	       push @pkg_ids, $pkg_id;
	    }
        }
    } elsif ($relationship =~ /srcpackages/) {
        for my $pkg (@{$pkgs}) {
	    my $pkg_id =
              $self->result_source->schema->resultset('SrcPkg')->
              get_src_pkg_id($pkg);
	    if (not defined $pkg_id) {
		push @unset_packages,$pkg;
	    } else {
		push @pkg_ids,$pkg_id;
	    }
        }
    } else {
        croak "Unsupported relationship $relationship";
    }
    @pkg_ids = uniq @pkg_ids;
    if ($relationship eq 'binpackages') {
        $self->set_binpackages([map {{id => $_}} @pkg_ids]);
    } elsif ($relationship eq 'srcpackages') {
        $self->set_srcpackages([map {{id => $_}} @pkg_ids]);
    } elsif ($relationship eq 'affects_binpackages') {
        $self->set_affects_binpackages([map {{id => $_}} @pkg_ids]);
    } elsif ($relationship eq 'affects_srcpackages') {
        $self->set_affects_srcpackages([map {{id => $_}} @pkg_ids]);
    } else {
        croak "Unsupported relationship $relationship";
    }
    return @unset_packages
}
# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
