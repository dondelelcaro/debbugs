
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
-- severities
CREATE TYPE bug_severity AS ENUM ('wishlist','minor','normal',
       'important','serious','grave','critical');

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
       ver TEXT NOT NULL,
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
       bin_pkg_id INT NOT NULL REFERENCES bin_pkg
            ON UPDATE CASCADE ON DELETE CASCADE,
       src_ver_id INT NOT NULL REFERENCES src_ver
            ON UPDATE CASCADE ON DELETE CASCADE,
       arch_id INT NOT NULL REFERENCES arch
       	    ON UPDATE CASCADE ON DELETE CASCADE,
       ver TEXT NOT NULL
);
CREATE INDEX bin_ver_ver_idx ON bin_ver(ver);
CREATE UNIQUE INDEX bin_ver_bin_pkg_id_arch_idx ON bin_ver(bin_pkg_id,arch_id);
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