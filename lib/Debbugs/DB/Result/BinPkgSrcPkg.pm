use utf8;
package Debbugs::DB::Result::BinPkgSrcPkg;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Debbugs::DB::Result::BinPkgSrcPkg - Binary package <-> source package mapping sumpmary table

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

=head1 TABLE: C<bin_pkg_src_pkg>

=cut

__PACKAGE__->table("bin_pkg_src_pkg");

=head1 ACCESSORS

=head2 bin_pkg

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

Binary package id (matches bin_pkg)

=head2 src_pkg

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

Source package id (matches src_pkg)

=cut

__PACKAGE__->add_columns(
  "bin_pkg",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "src_pkg",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);

=head1 UNIQUE CONSTRAINTS

=head2 C<bin_pkg_src_pkg_bin_pkg_src_pkg>

=over 4

=item * L</bin_pkg>

=item * L</src_pkg>

=back

=cut

__PACKAGE__->add_unique_constraint("bin_pkg_src_pkg_bin_pkg_src_pkg", ["bin_pkg", "src_pkg"]);

=head2 C<bin_pkg_src_pkg_src_pkg_bin_pkg>

=over 4

=item * L</src_pkg>

=item * L</bin_pkg>

=back

=cut

__PACKAGE__->add_unique_constraint("bin_pkg_src_pkg_src_pkg_bin_pkg", ["src_pkg", "bin_pkg"]);

=head1 RELATIONS

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

=head2 src_pkg

Type: belongs_to

Related object: L<Debbugs::DB::Result::SrcPkg>

=cut

__PACKAGE__->belongs_to(
  "src_pkg",
  "Debbugs::DB::Result::SrcPkg",
  { id => "src_pkg" },
  { is_deferrable => 0, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07048 @ 2018-04-18 16:55:56
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:O/v5RtjJF9SgxXEy76U/xw

sub sqlt_deploy_hook {
    my ($self, $sqlt_table) = @_;
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
	add_procedure(name => 'src_ver_to_src_pkg',
		      sql => <<'EOF',
CREATE OR REPLACE FUNCTION src_ver_to_src_pkg(src_ver INT) RETURNS INT
  AS $src_ver_to_src_pkg$
  DECLARE
  src_pkg int;
  BEGIN
	SELECT sv.src_pkg INTO STRICT src_pkg
	       FROM src_ver sv WHERE sv.id=src_ver;
	RETURN src_pkg;
  END
  $src_ver_to_src_pkg$ LANGUAGE plpgsql;
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

}

1;
