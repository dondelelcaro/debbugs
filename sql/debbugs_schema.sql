
DROP TABLE bug_tag CASCADE;
DROP TABLE tag CASCADE;
DROP TABLE bug CASCADE;
DROP TYPE bug_severity CASCADE;
DROP TABLE src_pkg CASCADE;
DROP TABLE bug_ver CASCADE;
DROP TABLE src_pkg_alias CASCADE;
DROP TABLE src_ver CASCADE;
DROP TABLE arch CASCADE;
DROP TABLE bin_ver CASCADE;
DROP TABLE bin_pkg CASCADE;
DROP TABLE bug_blocks CASCADE;
DROP TABLE bug_merged CASCADE;
DROP VIEW bug_package CASCADE;
DROP TABLE bug_srcpackage CASCADE;
DROP TABLE bug_binpackage CASCADE;
DROP VIEW  bug_package CASCADE;
DROP VIEW binary_versions CASCADE;
DROP TABLE suite CASCADE;
DROP TABLE bin_associations CASCADE;
DROP TABLE src_associations CASCADE;
DROP TABLE maintainer CASCADE;
DROP TABLE bug_message CASCADE;
DROP TABLE message_corespondent CASCADE;
DROP TABLE corespondent CASCADE;
DROP TABLE message_refs CASCADE;
DROP TABLE message CASCADE;
DROP TYPE message_corespondent_type CASCADE;
DROP TABLE table_comments CASCADE;
DROP TABLE column_comments CASCADE;

-- the following two tables are used to provide documentation about
-- the tables and columns for DBIx::Class::Schema::Loader
CREATE TABLE table_comments (
       table_name TEXT UNIQUE NOT NULL,
       comment_text TEXT NOT NULL
);
CREATE TABLE column_comments (
       table_name TEXT  NOT NULL,
       column_name TEXT  NOT NULL,
       comment_text TEXT NOT NULL
);
CREATE UNIQUE INDEX ON column_comments(table_name,column_name);

-- severities
CREATE TYPE bug_severity AS ENUM ('wishlist','minor','normal',
       'important','serious','grave','critical');

CREATE TABLE maintainer (
       id SERIAL PRIMARY KEY,
       name TEXT NOT NULL UNIQUE,
       created TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
       modified TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);
INSERT INTO table_comments  VALUES ('maintainer','Package maintainer names');
INSERT INTO column_comments VALUES ('maintainer','id','Package maintainer id');
INSERT INTO column_comments VALUES ('maintainer','name','Name of package maintainer');
INSERT INTO column_comments VALUES ('maintainer','created','Time maintainer record created');
INSERT INTO column_comments VALUES ('maintainer','modified','Time maintainer record modified');

-- bugs table
CREATE TABLE bug (
       id INTEGER NOT NULL PRIMARY KEY,
       creation TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
       log_modified TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
       last_modified TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
       archived BOOLEAN NOT NULL DEFAULT FALSE,
       unarchived TIMESTAMP WITH TIME ZONE,
       forwarded TEXT NOT NULL DEFAULT '',
       summary TEXT NOT NULL DEFAULT '',
       outlook TEXT NOT NULL DEFAULT '',
       subject TEXT NOT NULL,
       done TEXT NOT NULL DEFAULT '',
       owner TEXT NOT NULL DEFAULT '',
       unknown_packages TEXT NOT NULL DEfAULT '',
       severity bug_severity DEFAULT 'normal'::bug_severity
);
INSERT INTO table_comments VALUES ('bug','Bugs');
INSERT INTO column_comments VALUES ('bug','id','Bug number');
INSERT INTO column_comments VALUES ('bug','creation','Time bug created');
INSERT INTO column_comments VALUES ('bug','log_modified','Time bug log was last modified');
INSERT INTO column_comments VALUES ('bug','last_modified','Time bug status was last modified');
INSERT INTO column_comments VALUES ('bug','archived','True if bug has been archived');
INSERT INTO column_comments VALUES ('bug','unarchived','Time bug was last unarchived; null if bug has never been unarchived');
INSERT INTO column_comments VALUES ('bug','forwarded','Where bug has been forwarded to; empty if it has not been forwarded');
INSERT INTO column_comments VALUES ('bug','summary','Summary of the bug; empty if it has no summary');
INSERT INTO column_comments VALUES ('bug','outlook','Outlook of the bug; empty if it has no outlook');
INSERT INTO column_comments VALUES ('bug','subject','Subject of the bug');
INSERT INTO column_comments VALUES ('bug','done','Individual who did the -done; empty if it has never been -done');
INSERT INTO column_comments VALUES ('bug','owner','Individual who did the -done; empty if it has never been -done');
INSERT INTO column_comments VALUES ('bug','unknown_packages','Package name if the package is not known');
INSERT INTO column_comments VALUES ('bug','severity','Bug severity');



CREATE TABLE bug_blocks (
       bug_id INT NOT NULL REFERENCES bug,
       blocks INT NOT NULL REFERENCES bug,
       CONSTRAINT bug_doesnt_block_itself CHECK (bug_id <> blocks)
);
CREATE UNIQUE INDEX bug_blocks_bug_id_blocks_idx ON bug_blocks(bug_id,blocks);
CREATE INDEX bug_blocks_bug_id_idx ON bug_blocks(bug_id);
CREATE INDEX bug_blocks_blocks_idx ON bug_blocks(blocks);
INSERT INTO table_comments VALUES ('bug_blocks','Bugs which block other bugs');
INSERT INTO column_comments VALUES ('bug_blocks','bug_id','Bug number');
INSERT INTO column_comments VALUES ('bug_blocks','blocks','Bug number which is blocked by bug_id');


CREATE TABLE bug_merged (
       bug_id INT NOT NULL REFERENCES bug,
       merged INT NOT NULL REFERENCES bug,
       CONSTRAINT bug_doesnt_merged_itself CHECK (bug_id <> merged)
);
CREATE UNIQUE INDEX bug_merged_bug_id_merged_idx ON bug_merged(bug_id,merged);
CREATE INDEX bug_merged_bug_id_idx ON bug_merged(bug_id);
CREATE INDEX bug_merged_merged_idx ON bug_merged(merged);
INSERT INTO table_comments  VALUES ('bug_merged','Bugs which are merged with other bugs');
INSERT INTO column_comments VALUES ('bug_merged','bug_id','Bug number');
INSERT INTO column_comments VALUES ('bug_merged','merged','Bug number which is merged with bug_id');

CREATE TABLE src_pkg (
       id SERIAL PRIMARY KEY,
       pkg TEXT NOT NULL UNIQUE,
       pseduopkg BOOLEAN DEFAULT FALSE,
       alias_of INT REFERENCES src_pkg ON UPDATE CASCADE ON DELETE CASCADE
       CONSTRAINT src_pkg_doesnt_alias_itself CHECK (id <> alias_of)
);
INSERT INTO table_comments VALUES ('src_pkg','Source packages');
INSERT INTO column_comments VALUES ('src_pkg','id','Source package id');
INSERT INTO column_comments VALUES ('src_pkg','pkg','Source package name');
INSERT INTO column_comments VALUES ('src_pkg','pseudopkg','True if this is a pseudo package');
INSERT INTO column_comments VALUES ('src_pkg','alias_of','Source package id which this source package is an alias of');



CREATE TABLE src_ver (
       id SERIAL PRIMARY KEY,
       src_pkg_id INT NOT NULL REFERENCES src_pkg
            ON UPDATE CASCADE ON DELETE CASCADE,
       ver public.debversion NOT NULL,
       maintainer_id INT REFERENCES maintainer
            ON UPDATE CASCADE ON DELETE SET NULL,
       upload_date TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
       based_on INT REFERENCES src_ver
            ON UPDATE CASCADE ON DELETE CASCADE
);
CREATE UNIQUE INDEX src_ver_src_pkg_id_ver ON src_ver(src_pkg_id,ver);
INSERT INTO table_comments VALUES ('src_ver','Source Package versions');
INSERT INTO column_comments VALUES ('src_ver','id','Source package version id');
INSERT INTO column_comments VALUES ('src_ver','src_pkg_id','Source package id (matches src_pkg table)');
INSERT INTO column_comments VALUES ('src_ver','ver','Version of the source package');
INSERT INTO column_comments VALUES ('src_ver','maintainer_id','Maintainer id (matches maintainer table)');
INSERT INTO column_comments VALUES ('src_ver','upload_date','Date this version of the source package was uploaded');
INSERT INTO column_comments VALUES ('src_ver','based_on','Source package version this version is based on');



CREATE TABLE bug_ver (
       bug_id INT NOT NULL REFERENCES bug
         ON UPDATE CASCADE ON DELETE RESTRICT,
       ver_string TEXT,
       src_pkg_id INT REFERENCES src_pkg
            ON UPDATE CASCADE ON DELETE SET NULL,
       src_ver_id INT REFERENCES src_ver
            ON UPDATE CASCADE ON DELETE SET NULL,
       found BOOLEAN NOT NULL DEFAULT TRUE,
       creation TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
       last_modified TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);
CREATE INDEX bug_ver_src_pkg_id_idx ON bug_ver(src_pkg_id);
CREATE INDEX bug_ver_src_pkg_id_src_ver_id_idx ON bug_ver(src_pkg_id,src_ver_id);
CREATE INDEX bug_ver_src_ver_id_idx ON bug_ver(src_ver_id);
CREATE UNIQUE INDEX ON bug_ver(bug_id,ver_string,found);
INSERT INTO table_comments VALUES ('bug_ver','Bug versions');

CREATE TABLE arch (
       id SERIAL PRIMARY KEY,
       arch TEXT NOT NULL UNIQUE
);

CREATE TABLE bin_pkg (
       id SERIAL PRIMARY KEY,
       pkg TEXT NOT NULL UNIQUE
);

CREATE TABLE bin_ver(
       id SERIAL PRIMARY KEY,
       bin_pkg_id INT NOT NULL REFERENCES bin_pkg
            ON UPDATE CASCADE ON DELETE CASCADE,
       src_ver_id INT NOT NULL REFERENCES src_ver
            ON UPDATE CASCADE ON DELETE CASCADE,
       arch_id INT NOT NULL REFERENCES arch
       	    ON UPDATE CASCADE ON DELETE CASCADE,
       ver public.debversion NOT NULL
);
CREATE INDEX bin_ver_ver_idx ON bin_ver(ver);
CREATE UNIQUE INDEX bin_ver_bin_pkg_id_arch_idx ON bin_ver(bin_pkg_id,arch_id,ver);
CREATE UNIQUE INDEX bin_ver_src_ver_id_arch_idx ON bin_ver(src_ver_id,arch_id);
CREATE INDEX bin_ver_bin_pkg_id_idx ON bin_ver(bin_pkg_id);
CREATE INDEX bin_ver_src_ver_id_idx ON bin_ver(src_ver_id);

CREATE TABLE tag (
       id SERIAL PRIMARY KEY,
       tag TEXT NOT NULL UNIQUE,
       obsolete BOOLEAN DEFAULT FALSE
);

CREATE TABLE bug_tag (
       bug_id INT NOT NULL REFERENCES bug,
       tag_id INT NOT NULL REFERENCES tag
);

CREATE UNIQUE INDEX bug_tag_bug_tag_id ON bug_tag (bug_id,tag_id);
CREATE INDEX bug_tag_tag_id ON bug_tag (tag_id);
CREATE INDEX bug_tag_bug_id ON bug_tag (bug_id);

CREATE TABLE bug_binpackage (
       bug_id INT NOT NULL REFERENCES bug,
       bin_pkg_id INT NOT NULL REFERENCES bin_pkg
);
CREATE UNIQUE INDEX bug_binpackage_id_pkg_id ON bug_binpackage(bug_id,bin_pkg_id);

CREATE TABLE bug_srcpackage (
       bug_id INT NOT NULL REFERENCES bug,
       src_pkg_id INT NOT NULL REFERENCES src_pkg ON UPDATE CASCADE ON DELETE CASCADE
);
CREATE UNIQUE INDEX bug_srcpackage_id_pkg_id ON bug_srcpackage(bug_id,src_pkg_id);

CREATE VIEW bug_package (bug_id,pkg_id,pkg_type,package) AS
       SELECT b.bug_id,b.bin_pkg_id,'binary',bp.pkg FROM bug_binpackage b JOIN bin_pkg bp ON bp.id=b.bin_pkg_id UNION
              SELECT s.bug_id,s.src_pkg_id,'source',sp.pkg FROM bug_srcpackage s JOIN src_pkg sp ON sp.id=s.src_pkg_id;

CREATE VIEW binary_versions (src_pkg, src_ver, bin_pkg, arch, bin_ver) AS
       SELECT sp.pkg AS src_pkg, sv.ver AS src_ver, bp.pkg AS bin_pkg, a.arch AS arch, b.ver AS bin_ver
       FROM bin_ver b JOIN arch a ON b.arch_id = a.id
       	              JOIN bin_pkg bp ON b.bin_pkg_id  = bp.id
                      JOIN src_ver sv ON b.src_ver_id  = sv.id
                      JOIN src_pkg sp ON sv.src_pkg_id = sp.id;

CREATE TABLE suite (
       id SERIAL PRIMARY KEY,
       suite_name TEXT NOT NULL UNIQUE,
       version TEXT,
       codename TEXT,
       active BOOLEAN DEFAULT TRUE);
CREATE INDEX ON suite(codename);
CREATE INDEX ON suite(version);

CREATE TABLE bin_associations (
       id SERIAL PRIMARY KEY,
       suite INT NOT NULL REFERENCES suite ON DELETE CASCADE ON UPDATE CASCADE,
       bin INT NOT NULL REFERENCES bin_ver ON DELETE CASCADE ON UPDATE CASCADE,
       created TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
       modified TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

CREATE TABLE src_associations (
       id SERIAL PRIMARY KEY,
       suite INT NOT NULL REFERENCES suite ON DELETE CASCADE ON UPDATE CASCADE,
       source INT NOT NULL REFERENCES src_ver ON DELETE CASCADE ON UPDATE CASCADE,
       created TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
       modified TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

CREATE TABLE message (
       id SERIAL PRIMARY KEY,
       msgid TEXT,
       from_complete TEXT,
       from_addr TEXT,
       to_complete TEXT,
       to_addr TEXT,
       subject TEXT NOT NULL DEFAULT '',
       sent_date TIMESTAMP WITH TIME ZONE,
       refs TEXT NOT NULL DEFAULT '',
       spam_score FLOAT,
       is_spam BOOLEAN DEFAULT FALSE
);

CREATE TABLE message_refs (
       message INT NOT NULL REFERENCES message ON DELETE CASCADE ON UPDATE CASCADE,
       refs INT NOT NULL REFERENCES message ON DELETE CASCADE ON UPDATE CASCADE,
       CONSTRAINT message_doesnt_reference_itself CHECK (message <> refs)
);

CREATE TABLE corespondent (
       id SERIAL PRIMARY KEY,
       addr TEXT NOT NULL UNIQUE
);

CREATE TYPE message_corespondent_type AS ENUM ('to','from','envfrom','cc');

CREATE TABLE message_corespondent (
       message INT NOT NULL REFERENCES message ON DELETE CASCADE ON UPDATE CASCADE,
       corespondent INT NOT NULL REFERENCES corespondent ON DELETE CASCADE ON UPDATE CASCADE,
       corespondent_type message_corespondent_type NOT NULL DEFAULT 'to'
);

CREATE UNIQUE INDEX ON message_corespondent(message,corespondent,corespondent_type);
CREATE INDEX ON message_corespondent(corespondent);

CREATE TABLE bug_message (
       bug INT NOT NULL REFERENCES bug ON DELETE CASCADE ON UPDATE CASCADE,
       message INT NOT NULL REFERENCES message ON DELETE CASCADE ON UPDATE CASCADE,
       message_number INT NOT NULL,
       bug_log_offset INT
);

