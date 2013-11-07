
DROP TABLE bug_status_cache CASCADE;
DROP VIEW  bug_package CASCADE;
DROP VIEW binary_versions CASCADE;
DROP TABLE bug_tag CASCADE;
DROP TABLE tag CASCADE;
DROP TABLE severity CASCADE;
DROP TABLE bug CASCADE;
DROP TABLE src_pkg CASCADE;
DROP TABLE bug_ver CASCADE;
DROP TABLE src_ver CASCADE;
DROP TABLE arch CASCADE;
DROP TABLE bin_ver CASCADE;
DROP TABLE bin_pkg CASCADE;
DROP TABLE bug_blocks CASCADE;
DROP TABLE bug_merged CASCADE;
DROP TABLE bug_srcpackage CASCADE;
DROP TABLE bug_binpackage CASCADE;
DROP TABLE suite CASCADE;
DROP TABLE bin_associations CASCADE;
DROP TABLE src_associations CASCADE;
DROP TABLE maintainer CASCADE;
DROP TABLE bug_message CASCADE;
DROP TABLE message_correspondent CASCADE;
DROP TABLE correspondent_full_name CASCADE;
DROP TABLE correspondent CASCADE;
DROP TABLE message_refs CASCADE;
DROP TABLE message CASCADE;
DROP TYPE message_correspondent_type CASCADE;
DROP TABLE table_comments CASCADE;
DROP TABLE column_comments CASCADE;
DROP TYPE bug_status_type CASCADE;

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


CREATE TABLE correspondent (
       id SERIAL PRIMARY KEY,
       addr TEXT NOT NULL UNIQUE
);
INSERT INTO table_comments VALUES ('correspondent','Individual who has corresponded with the BTS');
INSERT INTO column_comments VALUES ('correspondent','id','Correspondent ID');
INSERT INTO column_comments VALUES ('correspondent','addr','Correspondent address');

CREATE TABLE maintainer (
       id SERIAL PRIMARY KEY,
       name TEXT NOT NULL UNIQUE,
       correspondent INT NOT NULL REFERENCES correspondent(id),
       created TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
       modified TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);
INSERT INTO table_comments  VALUES ('maintainer','Package maintainer names');
INSERT INTO column_comments VALUES ('maintainer','id','Package maintainer id');
INSERT INTO column_comments VALUES ('maintainer','name','Name of package maintainer');
INSERT INTO column_comments VALUES ('maintainer','correspondent','Correspondent ID');
INSERT INTO column_comments VALUES ('maintainer','created','Time maintainer record created');
INSERT INTO column_comments VALUES ('maintainer','modified','Time maintainer record modified');


CREATE TABLE severity (
       id SERIAL PRIMARY KEY,
       severity TEXT NOT NULL UNIQUE,
       ordering INT NOT NULL DEFAULT 5,
       strong BOOLEAN DEFAULT FALSE,
       obsolete BOOLEAN DEFAULT FALSE
);
INSERT INTO table_comments VALUES ('severity','Bug severity');
INSERT INTO column_comments VALUES ('severity','id','Severity id');
INSERT INTO column_comments VALUES ('severity','severity','Severity name');
INSERT INTO column_comments VALUES ('severity','ordering','Severity ordering (more severe severities have higher numbers)');
INSERT INTO column_comments VALUES ('severity','strong','True if severity is a strong severity');
INSERT INTO column_comments VALUES ('severity','obsolete','Whether a severity level is obsolete (should not be set on new bugs)');

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
       severity INT NOT NULL REFERENCES severity(id),
       done INT REFERENCES correspondent(id),
       done_full TEXT NOT NULL DEFAULT '',
       owner INT REFERENCES correspondent(id),
       owner_full TEXT NOT NULL DEFAULT '',
       -- submitter would ideally be NOT NULL, but there are some ancient bugs which do not have submitters
       submitter INT REFERENCES correspondent(id),
       submitter_full TEXT NOT NULL DEFAULT '',
       unknown_packages TEXT NOT NULL DEfAULT ''
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
INSERT INTO column_comments VALUES ('bug','owner','Individual who owns this bug; empty if no one owns it');
INSERT INTO column_comments VALUES ('bug','submitter','Individual who submitted this bug; empty if there is no submitter');
INSERT INTO column_comments VALUES ('bug','unknown_packages','Package name if the package is not known');

CREATE INDEX ON bug(creation);
CREATE INDEX ON bug(log_modified);
CREATE INDEX ON bug(done);
CREATE INDEX ON bug(owner);
CREATE INDEX ON bug(submitter);
CREATE INDEX ON bug(forwarded);



CREATE TABLE bug_blocks (
       id SERIAL PRIMARY KEY,
       bug INT NOT NULL REFERENCES bug,
       blocks INT NOT NULL REFERENCES bug,
       CONSTRAINT bug_doesnt_block_itself CHECK (bug <> blocks)
);
CREATE UNIQUE INDEX bug_blocks_bug_id_blocks_idx ON bug_blocks(bug,blocks);
CREATE INDEX bug_blocks_bug_id_idx ON bug_blocks(bug);
CREATE INDEX bug_blocks_blocks_idx ON bug_blocks(blocks);
INSERT INTO table_comments VALUES ('bug_blocks','Bugs which block other bugs');
INSERT INTO column_comments VALUES ('bug_blocks','bug','Bug number');
INSERT INTO column_comments VALUES ('bug_blocks','blocks','Bug number which is blocked by bug');


CREATE TABLE bug_merged (
       id SERIAL PRIMARY KEY,
       bug INT NOT NULL REFERENCES bug,
       merged INT NOT NULL REFERENCES bug,
       CONSTRAINT bug_doesnt_merged_itself CHECK (bug <> merged)
);
CREATE UNIQUE INDEX bug_merged_bug_id_merged_idx ON bug_merged(bug,merged);
CREATE INDEX bug_merged_bug_id_idx ON bug_merged(bug);
CREATE INDEX bug_merged_merged_idx ON bug_merged(merged);
INSERT INTO table_comments  VALUES ('bug_merged','Bugs which are merged with other bugs');
INSERT INTO column_comments VALUES ('bug_merged','bug','Bug number');
INSERT INTO column_comments VALUES ('bug_merged','merged','Bug number which is merged with bug');

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
       src_pkg INT NOT NULL REFERENCES src_pkg
            ON UPDATE CASCADE ON DELETE CASCADE,
       ver public.debversion NOT NULL,
       maintainer_id INT REFERENCES maintainer
            ON UPDATE CASCADE ON DELETE SET NULL,
       upload_date TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
       based_on INT REFERENCES src_ver
            ON UPDATE CASCADE ON DELETE CASCADE
);
CREATE UNIQUE INDEX src_ver_src_pkg_id_ver ON src_ver(src_pkg,ver);
INSERT INTO table_comments VALUES ('src_ver','Source Package versions');
INSERT INTO column_comments VALUES ('src_ver','id','Source package version id');
INSERT INTO column_comments VALUES ('src_ver','src_pkg','Source package id (matches src_pkg table)');
INSERT INTO column_comments VALUES ('src_ver','ver','Version of the source package');
INSERT INTO column_comments VALUES ('src_ver','maintainer_id','Maintainer id (matches maintainer table)');
INSERT INTO column_comments VALUES ('src_ver','upload_date','Date this version of the source package was uploaded');
INSERT INTO column_comments VALUES ('src_ver','based_on','Source package version this version is based on');



CREATE TABLE bug_ver (
       bug INT NOT NULL REFERENCES bug
         ON UPDATE CASCADE ON DELETE RESTRICT,
       ver_string TEXT,
       src_pkg INT REFERENCES src_pkg
            ON UPDATE CASCADE ON DELETE SET NULL,
       src_ver_id INT REFERENCES src_ver
            ON UPDATE CASCADE ON DELETE SET NULL,
       found BOOLEAN NOT NULL DEFAULT TRUE,
       creation TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
       last_modified TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);
CREATE INDEX bug_ver_src_pkg_id_idx ON bug_ver(src_pkg);
CREATE INDEX bug_ver_src_pkg_id_src_ver_id_idx ON bug_ver(src_pkg,src_ver_id);
CREATE INDEX bug_ver_src_ver_id_idx ON bug_ver(src_ver_id);
CREATE UNIQUE INDEX ON bug_ver(bug,ver_string,found);
INSERT INTO table_comments VALUES ('bug_ver','Bug versions');
INSERT INTO column_comments VALUES ('bug_ver','bug','Bug number');
INSERT INTO column_comments VALUES ('bug_ver','ver_string','Version string');
INSERT INTO column_comments VALUES ('bug_ver','src_pkg','Source package id (matches src_pkg table)');
INSERT INTO column_comments VALUES ('bug_ver','src_ver_id','Source package version id (matches src_ver table)');
INSERT INTO column_comments VALUES ('bug_ver','found','True if this is a found version; false if this is a fixed version');
INSERT INTO column_comments VALUES ('bug_ver','creation','Time that this entry was created');
INSERT INTO column_comments VALUES ('bug_ver','last_modified','Time that this entry was modified');


CREATE TABLE arch (
       id SERIAL PRIMARY KEY,
       arch TEXT NOT NULL UNIQUE
);
INSERT INTO table_comments VALUES ('arch','Architectures');
INSERT INTO column_comments VALUES ('arch','id','Architecture id');
INSERT INTO column_comments VALUES ('arch','arch','Architecture name');


CREATE TABLE bin_pkg (
       id SERIAL PRIMARY KEY,
       pkg TEXT NOT NULL UNIQUE
);
INSERT INTO table_comments VALUES ('bin_pkg','Binary packages');
INSERT INTO column_comments VALUES ('bin_pkg','id','Binary package id');
INSERT INTO column_comments VALUES ('bin_pkg','pkg','Binary package name');


CREATE TABLE bin_ver(
       id SERIAL PRIMARY KEY,
       bin_pkg INT NOT NULL REFERENCES bin_pkg
            ON UPDATE CASCADE ON DELETE CASCADE,
       src_ver_id INT NOT NULL REFERENCES src_ver
            ON UPDATE CASCADE ON DELETE CASCADE,
       arch_id INT NOT NULL REFERENCES arch
       	    ON UPDATE CASCADE ON DELETE CASCADE,
       ver public.debversion NOT NULL
);
CREATE INDEX bin_ver_ver_idx ON bin_ver(ver);
CREATE UNIQUE INDEX bin_ver_bin_pkg_id_arch_idx ON bin_ver(bin_pkg,arch_id,ver);
CREATE UNIQUE INDEX bin_ver_src_ver_id_arch_idx ON bin_ver(src_ver_id,arch_id);
CREATE INDEX bin_ver_bin_pkg_id_idx ON bin_ver(bin_pkg);
CREATE INDEX bin_ver_src_ver_id_idx ON bin_ver(src_ver_id);
INSERT INTO table_comments VALUES ('bin_ver','Binary versions');
INSERT INTO column_comments VALUES ('bin_ver','id','Binary version id');
INSERT INTO column_comments VALUES ('bin_ver','bin_pkg','Binary package id (matches bin_pkg)');
INSERT INTO column_comments VALUES ('bin_ver','src_ver_id','Source version (matchines src_ver)');
INSERT INTO column_comments VALUES ('bin_ver','arch_id','Architecture id (matches arch)');
INSERT INTO column_comments VALUES ('bin_ver','ver','Binary version');

CREATE TABLE tag (
       id SERIAL PRIMARY KEY,
       tag TEXT NOT NULL UNIQUE,
       obsolete BOOLEAN DEFAULT FALSE
);
INSERT INTO table_comments VALUES ('tag','Bug tags');
INSERT INTO column_comments VALUES ('tag','id','Tag id');
INSERT INTO column_comments VALUES ('tag','tag','Tag name');
INSERT INTO column_comments VALUES ('tag','obsolete','Whether a tag is obsolete (should not be set on new bugs)');

CREATE TABLE bug_tag (
       id SERIAL PRIMARY KEY,
       bug INT NOT NULL REFERENCES bug,
       tag INT NOT NULL REFERENCES tag
);
INSERT INTO table_comments VALUES ('bug_tag','Bug <-> tag mapping');
INSERT INTO column_comments VALUES ('bug_tag','bug','Bug id (matches bug)');
INSERT INTO column_comments VALUES ('bug_tag','tag','Tag id (matches tag)');

CREATE UNIQUE INDEX bug_tag_bug_tag_id ON bug_tag (bug,tag);
CREATE INDEX bug_tag_tag_id ON bug_tag (tag);
CREATE INDEX bug_tag_bug_id ON bug_tag (bug);



CREATE TABLE bug_binpackage (
       id SERIAL PRIMARY KEY,
       bug INT NOT NULL REFERENCES bug,
       bin_pkg INT NOT NULL REFERENCES bin_pkg
);
CREATE UNIQUE INDEX bug_binpackage_id_pkg_id ON bug_binpackage(bug,bin_pkg);
INSERT INTO table_comments VALUES ('bug_binpackage','Bug <-> binary package mapping');
INSERT INTO column_comments VALUES ('bug_binpackage','bug','Bug id (matches bug)');
INSERT INTO column_comments VALUES ('bug_binpackage','bin_pkg','Binary package id (matches bin_pkg)');

CREATE TABLE bug_srcpackage (
       id SERIAL PRIMARY KEY,
       bug INT NOT NULL REFERENCES bug,
       src_pkg INT NOT NULL REFERENCES src_pkg ON UPDATE CASCADE ON DELETE CASCADE
);
CREATE UNIQUE INDEX bug_srcpackage_id_pkg_id ON bug_srcpackage(bug,src_pkg);
INSERT INTO table_comments VALUES ('bug_srcpackage','Bug <-> source package mapping');
INSERT INTO column_comments VALUES ('bug_srcpackage','bug','Bug id (matches bug)');
INSERT INTO column_comments VALUES ('bug_srcpackage','src_pkg','Source package id (matches src_pkg)');

CREATE VIEW bug_package (bug,pkg_id,pkg_type,package) AS
       SELECT b.bug,b.bin_pkg,'binary',bp.pkg FROM bug_binpackage b JOIN bin_pkg bp ON bp.id=b.bin_pkg UNION
              SELECT s.bug,s.src_pkg,'source',sp.pkg FROM bug_srcpackage s JOIN src_pkg sp ON sp.id=s.src_pkg;

CREATE VIEW binary_versions (src_pkg, src_ver, bin_pkg, arch, bin_ver) AS
       SELECT sp.pkg AS src_pkg, sv.ver AS src_ver, bp.pkg AS bin_pkg, a.arch AS arch, b.ver AS bin_ver,
       svb.ver AS src_ver_based_on, spb.pkg AS src_pkg_based_on
       FROM bin_ver b JOIN arch a ON b.arch_id = a.id
       	              JOIN bin_pkg bp ON b.bin_pkg  = bp.id
                      JOIN src_ver sv ON b.src_ver_id  = sv.id
                      JOIN src_pkg sp ON sv.src_pkg = sp.id
                      LEFT OUTER JOIN src_ver svb ON sv.based_on = svb.id
                      LEFT OUTER JOIN src_pkg spb ON spb.id = svb.src_pkg;

CREATE TABLE suite (
       id SERIAL PRIMARY KEY,
       suite_name TEXT NOT NULL UNIQUE,
       version TEXT,
       codename TEXT,
       active BOOLEAN DEFAULT TRUE);
CREATE INDEX ON suite(codename);
CREATE INDEX ON suite(version);
INSERT INTO table_comments VALUES ('suite','Debian Release Suite (stable, testing, etc.)');
INSERT INTO column_comments VALUES ('suite','id','Suite id');
INSERT INTO column_comments VALUES ('suite','suite_name','Suite name');
INSERT INTO column_comments VALUES ('suite','version','Suite version; NULL if there is no appropriate version');
INSERT INTO column_comments VALUES ('suite','codename','Suite codename');
INSERT INTO column_comments VALUES ('suite','active','TRUE if the suite is still accepting uploads');

CREATE TABLE bin_associations (
       id SERIAL PRIMARY KEY,
       suite INT NOT NULL REFERENCES suite ON DELETE CASCADE ON UPDATE CASCADE,
       bin INT NOT NULL REFERENCES bin_ver ON DELETE CASCADE ON UPDATE CASCADE,
       created TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
       modified TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);
INSERT INTO table_comments VALUES ('bin_associations','Binary <-> suite associations');
INSERT INTO column_comments VALUES ('bin_associations','id','Binary <-> suite association id');
INSERT INTO column_comments VALUES ('bin_associations','suite','Suite id (matches suite)');
INSERT INTO column_comments VALUES ('bin_associations','bin','Binary version id (matches bin_ver)');
INSERT INTO column_comments VALUES ('bin_associations','created','Time this binary package entered this suite');
INSERT INTO column_comments VALUES ('bin_associations','modified','Time this entry was modified');

CREATE TABLE src_associations (
       id SERIAL PRIMARY KEY,
       suite INT NOT NULL REFERENCES suite ON DELETE CASCADE ON UPDATE CASCADE,
       source INT NOT NULL REFERENCES src_ver ON DELETE CASCADE ON UPDATE CASCADE,
       created TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
       modified TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);
INSERT INTO table_comments VALUES ('src_associations','Source <-> suite associations');
INSERT INTO column_comments VALUES ('src_associations','id','Source <-> suite association id');
INSERT INTO column_comments VALUES ('src_associations','suite','Suite id (matches suite)');
INSERT INTO column_comments VALUES ('src_associations','source','Source version id (matches src_ver)');
INSERT INTO column_comments VALUES ('src_associations','created','Time this source package entered this suite');
INSERT INTO column_comments VALUES ('src_associations','modified','Time this entry was modified');



CREATE TYPE bug_status_type AS ENUM ('pending','forwarded','pending-fixed','fixed','absent','done');
CREATE TABLE bug_status_cache (
       id SERIAL PRIMARY KEY,
       bug INT NOT NULL REFERENCES bug ON DELETE CASCADE ON UPDATE CASCADE,
       suite INT REFERENCES suite ON DELETE CASCADE ON UPDATE CASCADE,
       arch INT REFERENCES arch ON DELETE CASCADE ON UPDATE CASCADE,
       status bug_status_type NOT NULL,
       modified TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
       asof TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);
CREATE UNIQUE INDEX ON bug_status_cache(bug,suite,arch);
CREATE INDEX ON bug_status_cache(bug);
CREATE INDEX ON bug_status_cache(status);
INSERT INTO table_comments  VALUES ('bug_status_cache','Source <-> suite associations');
INSERT INTO column_comments VALUES ('bug_status_cache','id','Source <-> suite association id');
INSERT INTO column_comments VALUES ('bug_status_cache','bug','Source <-> suite association id');
INSERT INTO column_comments VALUES ('bug_status_cache','suite','Source <-> suite association id');
INSERT INTO column_comments VALUES ('bug_status_cache','arch','Source <-> suite association id');
INSERT INTO column_comments VALUES ('bug_status_cache','status','Source <-> suite association id');
INSERT INTO column_comments VALUES ('bug_status_cache','modified','Source <-> suite association id');
INSERT INTO column_comments VALUES ('bug_status_cache','asof','Source <-> suite association id');



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
INSERT INTO table_comments VALUES ('message','Messages sent to bugs');
INSERT INTO column_comments VALUES ('message','id','Message id');
INSERT INTO column_comments VALUES ('message','msgid','Message id header');
INSERT INTO column_comments VALUES ('message','from_complete','Complete from header of message');
INSERT INTO column_comments VALUES ('message','from_addr','Address(es) of From: headers');
INSERT INTO column_comments VALUES ('message','to_complete','Complete to header of message');
INSERT INTO column_comments VALUES ('message','to_addr','Address(es) of To: header');
INSERT INTO column_comments VALUES ('message','subject','Subject of the message');
INSERT INTO column_comments VALUES ('message','sent_date','Time/date message was sent (from Date header)');
INSERT INTO column_comments VALUES ('message','refs','Contents of References: header');
INSERT INTO column_comments VALUES ('message','spam_score','Spam score from spamassassin');
INSERT INTO column_comments VALUES ('message','is_spam','True if this message was spam and should not be shown');

CREATE INDEX ON message(msgid);

CREATE TABLE message_refs (
       id SERIAL PRIMARY KEY,
       message INT NOT NULL REFERENCES message ON DELETE CASCADE ON UPDATE CASCADE,
       refs INT NOT NULL REFERENCES message ON DELETE CASCADE ON UPDATE CASCADE,
       inferred BOOLEAN DEFAULT FALSE,
       primary_ref BOOLEAN DEFAULT FALSE,
       CONSTRAINT message_doesnt_reference_itself CHECK (message <> refs)
);
CREATE UNIQUE INDEX ON message_refs(message,refs);
CREATE INDEX ON message_refs(refs);
CREATE INDEX ON message_refs(message);
INSERT INTO table_comments VALUES ('message_refs','Message references');
INSERT INTO column_comments VALUES ('message_refs','message','Message id (matches message)');
INSERT INTO column_comments VALUES ('message_refs','refs','Reference id (matches message)');
INSERT INTO column_comments VALUES ('message_refs','inferred','TRUE if this message reference was reconstructed; primarily of use for messages which lack In-Reply-To: or References: headers');
INSERT INTO column_comments VALUES ('message_refs','primary_ref','TRUE if this message->ref came from In-Reply-To: or similar.');



CREATE TABLE correspondent_full_name(
       id SERIAL PRIMARY KEY,
       correspondent INT NOT NULL REFERENCES correspondent ON DELETE CASCADE ON UPDATE CASCADE,
       full_name TEXT NOT NULL
);
CREATE UNIQUE INDEX ON correspondent_full_name(correspondent,full_name);

INSERT INTO table_comments VALUES ('correspondent_full_name','Full names of BTS correspondents');
INSERT INTO column_comments VALUES ('correspondent_full_name','id','Correspondent full name id');
INSERT INTO column_comments VALUES ('correspondent_full_name','correpsondent','Correspondent ID (matches correspondent)');
INSERT INTO column_comments VALUES ('correspondent_full_name','full_name','Correspondent full name (includes e-mail address)');

CREATE TYPE message_correspondent_type AS ENUM ('to','from','envfrom','cc');

CREATE TABLE message_correspondent (
       id SERIAL PRIMARY KEY,
       message INT NOT NULL REFERENCES message ON DELETE CASCADE ON UPDATE CASCADE,
       correspondent INT NOT NULL REFERENCES correspondent ON DELETE CASCADE ON UPDATE CASCADE,
       correspondent_type message_correspondent_type NOT NULL DEFAULT 'to'
);
INSERT INTO table_comments VALUES ('message_correspondent','Linkage between correspondent and message');
INSERT INTO column_comments VALUES ('message_correspondent','message','Message id (matches message)');
INSERT INTO column_comments VALUES ('message_correspondent','correspondent','Correspondent (matches correspondent)');
INSERT INTO column_comments VALUES ('message_correspondent','correspondent_type','Type of correspondent (to, from, envfrom, cc, etc.)');

CREATE UNIQUE INDEX ON message_correspondent(message,correspondent,correspondent_type);
CREATE INDEX ON message_correspondent(correspondent);
CREATE INDEX ON message_correspondent(message);

CREATE TABLE bug_message (
       id SERIAL PRIMARY KEY,
       bug INT NOT NULL REFERENCES bug ON DELETE CASCADE ON UPDATE CASCADE,
       message INT NOT NULL REFERENCES message ON DELETE CASCADE ON UPDATE CASCADE,
       message_number INT NOT NULL,
       bug_log_offset INT,
       offset_valid TIMESTAMP WITH TIME ZONE
);
INSERT INTO table_comments VALUES ('bug_mesage','Mapping between a bug and a message');
INSERT INTO column_comments VALUES ('bug_message','bug','Bug id (matches bug)');
INSERT INTO column_comments VALUES ('bug_message','message','Message id (matches message)');
INSERT INTO column_comments VALUES ('bug_message','message_number','Message number in the bug log');
INSERT INTO column_comments VALUES ('bug_message','bug_log_offset','Byte offset in the bug log');
INSERT INTO column_comments VALUES ('bug_message','offset_valid','Time offset was valid');

