
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
-- severities
CREATE TYPE bug_severity AS ENUM ('wishlist','minor','normal',
       'important','serious','grave','critical');

CREATE TABLE maintainer (
       id SERIAL PRIMARY KEY,
       name TEXT NOT NULL UNIQUE,
       created TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
       modified TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

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

CREATE TABLE bug_blocks (
       bug_id INT NOT NULL REFERENCES bug,
       blocks INT NOT NULL REFERENCES bug,
       CONSTRAINT bug_doesnt_block_itself CHECK (bug_id <> blocks)
);
CREATE UNIQUE INDEX bug_blocks_bug_id_blocks_idx ON bug_blocks(bug_id,blocks);
CREATE INDEX bug_blocks_bug_id_idx ON bug_blocks(bug_id);
CREATE INDEX bug_blocks_blocks_idx ON bug_blocks(blocks);

CREATE TABLE bug_merged (
       bug_id INT NOT NULL REFERENCES bug,
       merged INT NOT NULL REFERENCES bug,
       CONSTRAINT bug_doesnt_merged_itself CHECK (bug_id <> merged)
);
CREATE UNIQUE INDEX bug_merged_bug_id_merged_idx ON bug_merged(bug_id,merged);
CREATE INDEX bug_merged_bug_id_idx ON bug_merged(bug_id);
CREATE INDEX bug_merged_merged_idx ON bug_merged(merged);

CREATE TABLE src_pkg (
       id SERIAL PRIMARY KEY,
       pkg TEXT NOT NULL UNIQUE,
       pseduopkg BOOLEAN DEFAULT FALSE,
       alias_of INT REFERENCES src_pkg ON UPDATE CASCADE ON DELETE CASCADE
       CONSTRAINT src_pkg_doesnt_alias_itself CHECK (id <> alias_of)
);

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

