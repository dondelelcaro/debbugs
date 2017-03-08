
DROP TABLE bug_status_cache CASCADE;
DROP VIEW bug_package CASCADE;
DROP VIEW binary_versions CASCADE;
DROP TABLE bug_tag CASCADE;
DROP TABLE tag CASCADE;
DROP TABLE bug_user_tag CASCADE;
DROP TABLE user_tag CASCADE;
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
DROP TABLE bug_affects_binpackage CASCADE;
DROP TABLE bug_affects_srcpackage CASCADE;
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
       table_name TEXT NOT NULL,
       comment_text TEXT NOT NULL
);
CREATE UNIQUE INDEX table_comments_table_name_idx ON table_comments(table_name);
CREATE TABLE column_comments (
       table_name TEXT  NOT NULL,
       column_name TEXT  NOT NULL,
       comment_text TEXT NOT NULL
);
CREATE UNIQUE INDEX column_comments_table_name_column_name_idx ON column_comments(table_name,column_name);


CREATE TABLE correspondent (
       id SERIAL PRIMARY KEY,
       addr TEXT NOT NULL
);
CREATE UNIQUE INDEX correspondent_addr_idx ON correspondent(addr);
INSERT INTO table_comments VALUES ('correspondent','Individual who has corresponded with the BTS');
INSERT INTO column_comments VALUES ('correspondent','id','Correspondent ID');
INSERT INTO column_comments VALUES ('correspondent','addr','Correspondent address');

CREATE TABLE maintainer (
       id SERIAL PRIMARY KEY,
       name TEXT NOT NULL,
       correspondent INT NOT NULL REFERENCES correspondent(id),
       created TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
       modified TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);
CREATE UNIQUE INDEX maintainer_name_idx ON maintainer(name);
CREATE INDEX maintainer_idx_correspondent ON maintainer(correspondent);
INSERT INTO table_comments  VALUES ('maintainer','Package maintainer names');
INSERT INTO column_comments VALUES ('maintainer','id','Package maintainer id');
INSERT INTO column_comments VALUES ('maintainer','name','Name of package maintainer');
INSERT INTO column_comments VALUES ('maintainer','correspondent','Correspondent ID');
INSERT INTO column_comments VALUES ('maintainer','created','Time maintainer record created');
INSERT INTO column_comments VALUES ('maintainer','modified','Time maintainer record modified');


CREATE TABLE severity (
       id SERIAL PRIMARY KEY,
       severity TEXT NOT NULL,
       ordering INT NOT NULL DEFAULT 5,
       strong BOOLEAN DEFAULT FALSE,
       obsolete BOOLEAN DEFAULT FALSE
);
CREATE UNIQUE INDEX severity_severity_idx ON severity(severity);
CREATE INDEX severity_ordering_idx ON severity(ordering);
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
CREATE INDEX bug_idx_owner ON bug(owner);
CREATE INDEX bug_idx_submitter ON bug(submitter);
CREATE INDEX bug_idx_done ON bug(done);
CREATE INDEX bug_idx_forwarded ON bug(forwarded);
CREATE INDEX bug_idx_last_modified ON bug(last_modified);
CREATE INDEX bug_idx_severity ON bug(severity);
CREATE INDEX bug_idx_creation ON bug(creation);
CREATE INDEX bug_idx_log_modified ON bug(log_modified);

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
       pkg TEXT NOT NULL,
       pseduopkg BOOLEAN NOT NULL DEFAULT FALSE,
       alias_of INT REFERENCES src_pkg ON UPDATE CASCADE ON DELETE CASCADE,
       creation TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
       disabled TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT 'infinity'::timestamp with time zone,
       last_modified TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
       obsolete BOOLEAN NOT NULL DEFAULT FALSE,
       CONSTRAINT src_pkg_doesnt_alias_itself CHECK (id <> alias_of),
       CONSTRAINT src_pkg_is_obsolete_if_disabled CHECK (
	   (obsolete IS FALSE AND disabled='infinity'::timestamp with time zone) OR
	   (obsolete IS TRUE AND disabled < 'infinity'::timestamp with time zone))
);
CREATE INDEX src_pkg_pkg ON src_pkg(pkg);
CREATE UNIQUE INDEX src_pkg_pkg_null ON src_pkg(pkg) WHERE disabled='infinity'::timestamp with time zone;
CREATE UNIQUE INDEX src_pkg_pkg_disabled ON src_pkg(pkg,disabled);
INSERT INTO table_comments VALUES ('src_pkg','Source packages');
INSERT INTO column_comments VALUES ('src_pkg','id','Source package id');
INSERT INTO column_comments VALUES ('src_pkg','pkg','Source package name');
INSERT INTO column_comments VALUES ('src_pkg','pseudopkg','True if this is a pseudo package');
INSERT INTO column_comments VALUES ('src_pkg','alias_of','Source package id which this source package is an alias of');



CREATE TABLE src_ver (
       id SERIAL PRIMARY KEY,
       src_pkg INT NOT NULL REFERENCES src_pkg
            ON UPDATE CASCADE ON DELETE CASCADE,
       ver debversion NOT NULL,
       maintainer INT REFERENCES maintainer
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
INSERT INTO column_comments VALUES ('src_ver','maintainer','Maintainer id (matches maintainer table)');
INSERT INTO column_comments VALUES ('src_ver','upload_date','Date this version of the source package was uploaded');
INSERT INTO column_comments VALUES ('src_ver','based_on','Source package version this version is based on');



CREATE TABLE bug_ver (
       id SERIAL PRIMARY KEY,
       bug INT NOT NULL REFERENCES bug
         ON UPDATE CASCADE ON DELETE RESTRICT,
       ver_string TEXT,
       src_pkg INT REFERENCES src_pkg
            ON UPDATE CASCADE ON DELETE SET NULL,
       src_ver INT REFERENCES src_ver
            ON UPDATE CASCADE ON DELETE SET NULL,
       found BOOLEAN NOT NULL DEFAULT TRUE,
       creation TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
       last_modified TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);
CREATE INDEX bug_ver_src_pkg_id_idx ON bug_ver(src_pkg);
CREATE INDEX bug_ver_src_pkg_id_src_ver_id_idx ON bug_ver(src_pkg,src_ver);
CREATE INDEX bug_ver_src_ver_id_idx ON bug_ver(src_ver);
CREATE UNIQUE INDEX bug_ver_bug_ver_string_found_idx ON bug_ver(bug,ver_string,found);
INSERT INTO table_comments VALUES ('bug_ver','Bug versions');
INSERT INTO column_comments VALUES ('bug_ver','id','Bug version id');
INSERT INTO column_comments VALUES ('bug_ver','bug','Bug number');
INSERT INTO column_comments VALUES ('bug_ver','ver_string','Version string');
INSERT INTO column_comments VALUES ('bug_ver','src_pkg','Source package id (matches src_pkg table)');
INSERT INTO column_comments VALUES ('bug_ver','src_ver','Source package version id (matches src_ver table)');
INSERT INTO column_comments VALUES ('bug_ver','found','True if this is a found version; false if this is a fixed version');
INSERT INTO column_comments VALUES ('bug_ver','creation','Time that this entry was created');
INSERT INTO column_comments VALUES ('bug_ver','last_modified','Time that this entry was modified');


CREATE TABLE arch (
       id SERIAL PRIMARY KEY,
       arch TEXT NOT NULL
);
CREATE UNIQUE INDEX arch_arch_key ON arch(arch);
INSERT INTO table_comments VALUES ('arch','Architectures');
INSERT INTO column_comments VALUES ('arch','id','Architecture id');
INSERT INTO column_comments VALUES ('arch','arch','Architecture name');


CREATE TABLE bin_pkg (
       id SERIAL PRIMARY KEY,
       pkg TEXT NOT NULL
);
CREATE UNIQUE INDEX bin_pkg_pkg_key ON bin_pkg(pkg);
INSERT INTO table_comments VALUES ('bin_pkg','Binary packages');
INSERT INTO column_comments VALUES ('bin_pkg','id','Binary package id');
INSERT INTO column_comments VALUES ('bin_pkg','pkg','Binary package name');


CREATE TABLE bin_ver(
       id SERIAL PRIMARY KEY,
       bin_pkg INT NOT NULL REFERENCES bin_pkg
            ON UPDATE CASCADE ON DELETE CASCADE,
       src_ver INT NOT NULL REFERENCES src_ver
            ON UPDATE CASCADE ON DELETE CASCADE,
       arch INT NOT NULL REFERENCES arch
       	    ON UPDATE CASCADE ON DELETE CASCADE,
       ver debversion NOT NULL
);
CREATE INDEX bin_ver_ver_idx ON bin_ver(ver);
CREATE UNIQUE INDEX bin_ver_bin_pkg_id_arch_idx ON bin_ver(bin_pkg,arch,ver);
CREATE INDEX bin_ver_src_ver_id_arch_idx ON bin_ver(src_ver,arch);
CREATE INDEX bin_ver_bin_pkg_id_idx ON bin_ver(bin_pkg);
CREATE INDEX bin_ver_src_ver_id_idx ON bin_ver(src_ver);
INSERT INTO table_comments VALUES ('bin_ver','Binary versions');
INSERT INTO column_comments VALUES ('bin_ver','id','Binary version id');
INSERT INTO column_comments VALUES ('bin_ver','bin_pkg','Binary package id (matches bin_pkg)');
INSERT INTO column_comments VALUES ('bin_ver','src_ver','Source version (matchines src_ver)');
INSERT INTO column_comments VALUES ('bin_ver','arch','Architecture id (matches arch)');
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
       bug INT NOT NULL REFERENCES bug,
       tag INT NOT NULL REFERENCES tag
);
INSERT INTO table_comments VALUES ('bug_tag','Bug <-> tag mapping');
INSERT INTO column_comments VALUES ('bug_tag','bug','Bug id (matches bug)');
INSERT INTO column_comments VALUES ('bug_tag','tag','Tag id (matches tag)');

CREATE UNIQUE INDEX bug_tag_bug_tag ON bug_tag (bug,tag);
CREATE INDEX bug_tag_tag ON bug_tag (tag);
CREATE INDEX bug_tag_bug ON bug_tag (bug);

CREATE TABLE user_tag (
       id SERIAL PRIMARY KEY,
       tag TEXT NOT NULL,
       correspondent INT NOT NULL REFERENCES correspondent(id)
);
INSERT INTO table_comments VALUES ('user_tag','User bug tags');
INSERT INTO column_comments VALUES ('user_tag','id','User bug tag id');
INSERT INTO column_comments VALUES ('user_tag','tag','User bug tag name');
INSERT INTO column_comments VALUES ('user_tag','correspondent','User bug tag correspondent');

CREATE UNIQUE INDEX user_tag_tag_correspondent ON user_tag(tag,correspondent);
CREATE INDEX user_tag_correspondent ON user_tag(correspondent);

CREATE TABLE bug_user_tag (
       bug INT NOT NULL REFERENCES bug,
       user_tag INT NOT NULL REFERENCES user_tag
);
INSERT INTO table_comments VALUES ('bug_user_tag','Bug <-> user tag mapping');
INSERT INTO column_comments VALUES ('bug_user_tag','bug','Bug id (matches bug)');
INSERT INTO column_comments VALUES ('bug_user_tag','tag','User tag id (matches user_tag)');

CREATE UNIQUE INDEX bug_user_tag_bug_tag ON bug_user_tag (bug,user_tag);
CREATE INDEX bug_user_tag_tag ON bug_user_tag (user_tag);
CREATE INDEX bug_user_tag_bug ON bug_user_tag (bug);

CREATE TABLE bug_binpackage (
       bug INT NOT NULL REFERENCES bug,
       bin_pkg INT NOT NULL REFERENCES bin_pkg ON UPDATE CASCADE ON DELETE CASCADE
);
CREATE UNIQUE INDEX bug_binpackage_id_pkg ON bug_binpackage(bug,bin_pkg);
INSERT INTO table_comments VALUES ('bug_binpackage','Bug <-> binary package mapping');
INSERT INTO column_comments VALUES ('bug_binpackage','bug','Bug id (matches bug)');
INSERT INTO column_comments VALUES ('bug_binpackage','bin_pkg','Binary package id (matches bin_pkg)');

CREATE TABLE bug_srcpackage (
       bug INT NOT NULL REFERENCES bug,
       src_pkg INT NOT NULL REFERENCES src_pkg ON UPDATE CASCADE ON DELETE CASCADE
);
CREATE UNIQUE INDEX bug_srcpackage_id_pkg ON bug_srcpackage(bug,src_pkg);
CREATE INDEX bug_srcpackage_idx_bug ON bug_srcpackage(bug);
CREATE INDEX bug_srcpackage_idx_src_pkg ON bug_srcpackage(src_pkg);

INSERT INTO table_comments VALUES ('bug_srcpackage','Bug <-> source package mapping');
INSERT INTO column_comments VALUES ('bug_srcpackage','bug','Bug id (matches bug)');
INSERT INTO column_comments VALUES ('bug_srcpackage','src_pkg','Source package id (matches src_pkg)');

CREATE VIEW bug_package (bug,pkg_id,pkg_type,package) AS
       SELECT b.bug,b.bin_pkg,'binary',bp.pkg FROM bug_binpackage b JOIN bin_pkg bp ON bp.id=b.bin_pkg UNION
              SELECT s.bug,s.src_pkg,'source',sp.pkg FROM bug_srcpackage s JOIN src_pkg sp ON sp.id=s.src_pkg;

CREATE TABLE bug_affects_binpackage (
       bug INT NOT NULL REFERENCES bug,
       bin_pkg INT NOT NULL REFERENCES bin_pkg ON UPDATE CASCADE ON DELETE CASCADE
);
CREATE UNIQUE INDEX bug_affects_binpackage_id_pkg ON bug_affects_binpackage(bug,bin_pkg);
INSERT INTO table_comments VALUES ('bug_affects_binpackage','Bug <-> binary package mapping');
INSERT INTO column_comments VALUES ('bug_affects_binpackage','bug','Bug id (matches bug)');
INSERT INTO column_comments VALUES ('bug_affects_binpackage','bin_pkg','Binary package id (matches bin_pkg)');

CREATE TABLE bug_affects_srcpackage (
       bug INT NOT NULL REFERENCES bug,
       src_pkg INT NOT NULL REFERENCES src_pkg ON UPDATE CASCADE ON DELETE CASCADE
);
CREATE UNIQUE INDEX bug_affects_srcpackage_id_pkg ON bug_affects_srcpackage(bug,src_pkg);
INSERT INTO table_comments VALUES ('bug_affects_srcpackage','Bug <-> source package mapping');
INSERT INTO column_comments VALUES ('bug_affects_srcpackage','bug','Bug id (matches bug)');
INSERT INTO column_comments VALUES ('bug_affects_srcpackage','src_pkg','Source package id (matches src_pkg)');

CREATE VIEW binary_versions (src_pkg, src_ver, bin_pkg, arch, bin_ver) AS
       SELECT sp.pkg AS src_pkg, sv.ver AS src_ver, bp.pkg AS bin_pkg, a.arch AS arch, b.ver AS bin_ver,
       svb.ver AS src_ver_based_on, spb.pkg AS src_pkg_based_on
       FROM bin_ver b JOIN arch a ON b.arch = a.id
       	              JOIN bin_pkg bp ON b.bin_pkg  = bp.id
                      JOIN src_ver sv ON b.src_ver  = sv.id
                      JOIN src_pkg sp ON sv.src_pkg = sp.id
                      LEFT OUTER JOIN src_ver svb ON sv.based_on = svb.id
                      LEFT OUTER JOIN src_pkg spb ON spb.id = svb.src_pkg;

CREATE TABLE suite (
       id SERIAL PRIMARY KEY,
       codename TEXT NOT NULL,
       suite_name TEXT,
       version TEXT,
       active BOOLEAN DEFAULT TRUE);
CREATE UNIQUE INDEX suite_idx_codename ON suite(codename);
CREATE UNIQUE INDEX suite_suite_name_key ON suite(suite_name);
CREATE UNIQUE INDEX suite_idx_version ON suite(version);
INSERT INTO table_comments VALUES ('suite','Debian Release Suite (stable, testing, etc.)');
INSERT INTO column_comments VALUES ('suite','id','Suite id');
INSERT INTO column_comments VALUES ('suite','suite_name','Suite name (testing, stable, etc.)');
INSERT INTO column_comments VALUES ('suite','version','Suite version; NULL if there is no appropriate version');
INSERT INTO column_comments VALUES ('suite','codename','Suite codename (sid, squeeze, etc.)');
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
CREATE UNIQUE INDEX bin_associations_bin_suite ON bin_associations(bin,suite);

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
CREATE UNIQUE INDEX src_associations_source_suite ON src_associations(source,suite);


CREATE TYPE bug_status_type AS ENUM ('pending','forwarded','pending-fixed','fixed','absent','done');
CREATE TABLE bug_status_cache (
       bug INT NOT NULL REFERENCES bug ON DELETE CASCADE ON UPDATE CASCADE,
       suite INT REFERENCES suite ON DELETE CASCADE ON UPDATE CASCADE,
       arch INT REFERENCES arch ON DELETE CASCADE ON UPDATE CASCADE,
       status bug_status_type NOT NULL,
       modified TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
       asof TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);
CREATE UNIQUE INDEX bug_status_cache_bug_suite_arch_idx ON bug_status_cache(bug,suite,arch);
CREATE INDEX bug_status_cache_idx_bug ON bug_status_cache(bug);
CREATE INDEX bug_status_cache_idx_status ON bug_status_cache(status);
CREATE INDEX bug_status_cache_idx_arch ON bug_status_cache(arch);
CREATE INDEX bug_status_cache_idx_suite ON bug_status_cache(suite);
INSERT INTO table_comments  VALUES ('bug_status_cache','Bug Status Cache');
INSERT INTO column_comments VALUES ('bug_status_cache','id','Bug status cache entry id');
INSERT INTO column_comments VALUES ('bug_status_cache','bug','Bug number (matches bug)');
INSERT INTO column_comments VALUES ('bug_status_cache','suite','Suite id (matches suite)');
INSERT INTO column_comments VALUES ('bug_status_cache','arch','Architecture id (matches arch)');
INSERT INTO column_comments VALUES ('bug_status_cache','status','Status (bug status)');
INSERT INTO column_comments VALUES ('bug_status_cache','modified','Time that this status was last modified');
INSERT INTO column_comments VALUES ('bug_status_cache','asof','Time that this status was last calculated');



CREATE TABLE message (
       id SERIAL PRIMARY KEY,
       msgid TEXT NOT NULL DEFAULT '',
       from_complete TEXT NOT NULL DEFAULT '',
       from_addr TEXT NOT NULL DEFAULT '',
       to_complete TEXT NOT NULL DEFAULT '',
       to_addr TEXT NOT NULL DEFAULT '',
       subject TEXT NOT NULL DEFAULT '',
       sent_date TIMESTAMP WITH TIME ZONE,
       refs TEXT NOT NULL DEFAULT '',
       spam_score FLOAT NOT NULL DEFAULT 0,
       is_spam BOOLEAN NOT NULL DEFAULT FALSE
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
CREATE INDEX message_msgid_idx ON message(msgid);
CREATE UNIQUE INDEX message_msgid_from_complete_to_complete_subject_idx
    ON message(msgid,from_complete,to_complete,subject);
CREATE INDEX message_subject_idx ON message(subject);

CREATE TABLE message_refs (
       message INT NOT NULL REFERENCES message ON DELETE CASCADE ON UPDATE CASCADE,
       refs INT NOT NULL REFERENCES message ON DELETE CASCADE ON UPDATE CASCADE,
       inferred BOOLEAN DEFAULT FALSE,
       primary_ref BOOLEAN DEFAULT FALSE,
       CONSTRAINT message_doesnt_reference_itself CHECK (message <> refs)
);
CREATE UNIQUE INDEX message_refs_message_refs_idx ON message_refs(message,refs);
CREATE INDEX message_refs_idx_refs ON message_refs(refs);
CREATE INDEX message_refs_idx_message ON message_refs(message);
INSERT INTO table_comments VALUES ('message_refs','Message references');
INSERT INTO column_comments VALUES ('message_refs','message','Message id (matches message)');
INSERT INTO column_comments VALUES ('message_refs','refs','Reference id (matches message)');
INSERT INTO column_comments VALUES ('message_refs','inferred','TRUE if this message reference was reconstructed; primarily of use for messages which lack In-Reply-To: or References: headers');
INSERT INTO column_comments VALUES ('message_refs','primary_ref','TRUE if this message->ref came from In-Reply-To: or similar.');



CREATE TABLE correspondent_full_name(
       id SERIAL PRIMARY KEY,
       correspondent INT NOT NULL REFERENCES correspondent ON DELETE CASCADE ON UPDATE CASCADE,
       full_name TEXT NOT NULL,
       last_seen TIMESTAMP NOT NULL DEFAULT NOW()
);
CREATE UNIQUE INDEX correspondent_full_name_correspondent_full_name_idx 
    ON correspondent_full_name(correspondent,full_name);
CREATE INDEX correspondent_full_name_idx_full_name ON correspondent_full_name(full_name);
CREATE INDEX correspondent_full_name_idx_last_seen ON correspondent_full_name(last_seen);
INSERT INTO table_comments VALUES ('correspondent_full_name','Full names of BTS correspondents');
INSERT INTO column_comments VALUES ('correspondent_full_name','id','Correspondent full name id');
INSERT INTO column_comments VALUES ('correspondent_full_name','correpsondent','Correspondent ID (matches correspondent)');
INSERT INTO column_comments VALUES ('correspondent_full_name','full_name','Correspondent full name (includes e-mail address)');

CREATE TYPE message_correspondent_type AS ENUM ('to','from','envfrom','cc');

CREATE TABLE message_correspondent (
       message INT NOT NULL REFERENCES message ON DELETE CASCADE ON UPDATE CASCADE,
       correspondent INT NOT NULL REFERENCES correspondent ON DELETE CASCADE ON UPDATE CASCADE,
       correspondent_type message_correspondent_type NOT NULL DEFAULT 'to'
);
INSERT INTO table_comments VALUES ('message_correspondent','Linkage between correspondent and message');
INSERT INTO column_comments VALUES ('message_correspondent','message','Message id (matches message)');
INSERT INTO column_comments VALUES ('message_correspondent','correspondent','Correspondent (matches correspondent)');
INSERT INTO column_comments VALUES ('message_correspondent','correspondent_type','Type of correspondent (to, from, envfrom, cc, etc.)');

CREATE UNIQUE INDEX message_correspondent_message_correspondent_correspondent_t_idx 
    ON message_correspondent(message,correspondent,correspondent_type);
CREATE INDEX message_correspondent_idx_correspondent ON message_correspondent(correspondent);
CREATE INDEX message_correspondent_idx_message ON message_correspondent(message);

CREATE TABLE bug_message (
       bug INT NOT NULL REFERENCES bug ON DELETE CASCADE ON UPDATE CASCADE,
       message INT NOT NULL REFERENCES message ON DELETE CASCADE ON UPDATE CASCADE,
       message_number INT NOT NULL,
       bug_log_offset INT,
       offset_valid TIMESTAMP WITH TIME ZONE
);
CREATE UNIQUE INDEX bug_message_bug_message_idx ON bug_message(bug,message);
CREATE INDEX bug_message_idx_bug_message_number ON bug_message(bug,message_number);
INSERT INTO table_comments VALUES ('bug_mesage','Mapping between a bug and a message');
INSERT INTO column_comments VALUES ('bug_message','bug','Bug id (matches bug)');
INSERT INTO column_comments VALUES ('bug_message','message','Message id (matches message)');
INSERT INTO column_comments VALUES ('bug_message','message_number','Message number in the bug log');
INSERT INTO column_comments VALUES ('bug_message','bug_log_offset','Byte offset in the bug log');
INSERT INTO column_comments VALUES ('bug_message','offset_valid','Time offset was valid');

