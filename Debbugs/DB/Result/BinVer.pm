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
    for my $idx (qw(ver bin_pkg src_ver)) {
	$sqlt_table->add_index(name => 'bin_ver_'.$idx.'_id_idx',
			       fields => [$idx]);
    }
    $sqlt_table->add_index(name => 'bin_ver_src_ver_id_arch_idx',
			   fields => [qw(src_ver arch)]
			  );
    $sqlt_table->schema->
	add_procedure(name => 'bin_ver_to_src_pkg',
		      sql => <<'EOF',
CREATE OR REPLACE FUNCTION bin_ver_to_src_pkg(bin_ver INT) RETURNS INT
  AS $src_pkg_from_bin_ver$
  DECLARE
  src_pkg int;
  BEGIN
	SELECT sv.src_pkg INTO STRICT src_pkg
	       FROM bin_ver bv JOIN src_ver sv ON bv.src_ver=sv.id
	       WHERE bv.id=bin_ver;
	RETURN src_pkg;
  END
  $src_pkg_from_bin_ver$ LANGUAGE plpgsql;
EOF
		     );
    $sqlt_table->schema->
	add_procedure(name => 'update_bin_pkg_src_pkg_bin_ver',
		      sql => <<'EOF',
CREATE OR REPLACE FUNCTION update_bin_pkg_src_pkg_bin_ver () RETURNS TRIGGER
  AS $update_bin_pkg_src_pkg_bin_ver$
  DECLARE
  src_ver_rows integer;
  BEGIN
  IF (TG_OP = 'DELETE' OR TG_OP = 'UPDATE' )  THEN
     -- if there is still a bin_ver with this src_pkg, then do nothing
     PERFORM * FROM bin_ver bv JOIN src_ver sv ON bv.src_ver = sv.id
     	    WHERE sv.id = OLD.src_ver LIMIT 2;
     GET DIAGNOSTICS src_ver_rows = ROW_COUNT;
     IF (src_ver_rows <= 1) THEN
        DELETE FROM bin_pkg_src_pkg
	       WHERE bin_pkg=OLD.bin_pkg AND
	       	     src_pkg=src_ver_to_src_pkg(OLD.src_ver);
     END IF;
  END IF;
  IF (TG_OP = 'INSERT' OR TG_OP = 'UPDATE') THEN
     BEGIN
     INSERT INTO bin_pkg_src_pkg (bin_pkg,src_pkg)
     	VALUES (NEW.bin_pkg,src_ver_to_src_pkg(NEW.src_ver))
	ON CONFLICT (bin_pkg,src_pkg) DO NOTHING;
     END;
  END IF;
  RETURN NULL;
  END
  $update_bin_pkg_src_pkg_bin_ver$ LANGUAGE plpgsql;
EOF
		     );
#     $sqlt_table->schema->
# 	add_trigger(name => 'bin_ver_update_bin_pkg_src_pkg',
# 		    perform_action_when => 'after',
# 		    database_events => [qw(INSERT UPDATE DELETE)],
# 		    on_table => 'bin_ver',
# 		    action => <<'EOF',
# FOR EACH ROW EXECUTE PROCEDURE update_bin_pkg_src_pkg_bin_ver();
# EOF
# 		   );
}

1;
