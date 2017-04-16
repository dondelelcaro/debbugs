-- 
-- Created by SQL::Translator::Producer::PostgreSQL
-- Created on Sat Apr 15 20:14:22 2017
-- 
;
--
-- Table: arch
--
CREATE TABLE "arch" (
  "id" serial NOT NULL,
  "arch" text NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "arch_arch_key" UNIQUE ("arch")
);

;
--
-- Table: bin_pkg
--
CREATE TABLE "bin_pkg" (
  "id" serial NOT NULL,
  "pkg" text NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "bin_pkg_pkg_key" UNIQUE ("pkg")
);

;
--
-- Table: column_comments
--
CREATE TABLE "column_comments" (
  "table_name" text NOT NULL,
  "column_name" text NOT NULL,
  "comment_text" text NOT NULL,
  CONSTRAINT "column_comments_table_name_column_name_idx" UNIQUE ("table_name", "column_name")
);

;
--
-- Table: correspondent
--
CREATE TABLE "correspondent" (
  "id" serial NOT NULL,
  "addr" text NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "correspondent_addr_idx" UNIQUE ("addr")
);

;
--
-- Table: message
--
CREATE TABLE "message" (
  "id" serial NOT NULL,
  "msgid" text DEFAULT '' NOT NULL,
  "from_complete" text DEFAULT '' NOT NULL,
  "to_complete" text DEFAULT '' NOT NULL,
  "subject" text DEFAULT '' NOT NULL,
  "sent_date" timestamp with time zone,
  "refs" text DEFAULT '' NOT NULL,
  "spam_score" double precision DEFAULT '0' NOT NULL,
  "is_spam" boolean DEFAULT false NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "message_msgid_from_complete_to_complete_subject_idx" UNIQUE ("msgid", "from_complete", "to_complete", "subject")
);
CREATE INDEX "message_msgid_idx" on "message" ("msgid");
CREATE INDEX "message_subject_idx" on "message" ("subject");

;
--
-- Table: severity
--
CREATE TABLE "severity" (
  "id" serial NOT NULL,
  "severity" text NOT NULL,
  "ordering" integer DEFAULT 5 NOT NULL,
  "strong" boolean DEFAULT false,
  "obsolete" boolean DEFAULT false,
  PRIMARY KEY ("id"),
  CONSTRAINT "severity_severity_idx" UNIQUE ("severity")
);
CREATE INDEX "severity_ordering_idx" on "severity" ("ordering");

;
--
-- Table: src_pkg
--
CREATE TABLE "src_pkg" (
  "id" serial NOT NULL,
  "pkg" text NOT NULL,
  "pseduopkg" boolean DEFAULT false NOT NULL,
  "alias_of" integer,
  "creation" timestamp with time zone DEFAULT current_timestamp NOT NULL,
  "disabled" timestamp with time zone DEFAULT 'infinity' NOT NULL,
  "last_modified" timestamp with time zone DEFAULT current_timestamp NOT NULL,
  "obsolete" boolean DEFAULT false NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "src_pkg_pkg_disabled" UNIQUE ("pkg", "disabled")
);
CREATE INDEX "src_pkg_idx_alias_of" on "src_pkg" ("alias_of");
CREATE INDEX "src_pkg_pkg" on "src_pkg" ("pkg");

;
--
-- Table: suite
--
CREATE TABLE "suite" (
  "id" serial NOT NULL,
  "codename" text NOT NULL,
  "suite_name" text,
  "version" text,
  "active" boolean DEFAULT true,
  PRIMARY KEY ("id"),
  CONSTRAINT "suite_idx_codename" UNIQUE ("codename"),
  CONSTRAINT "suite_idx_version" UNIQUE ("version"),
  CONSTRAINT "suite_suite_name_key" UNIQUE ("suite_name")
);

;
--
-- Table: table_comments
--
CREATE TABLE "table_comments" (
  "table_name" text NOT NULL,
  "comment_text" text NOT NULL,
  CONSTRAINT "table_comments_table_name_idx" UNIQUE ("table_name"),
  CONSTRAINT "table_comments_table_name_key" UNIQUE ("table_name")
);

;
--
-- Table: tag
--
CREATE TABLE "tag" (
  "id" serial NOT NULL,
  "tag" text NOT NULL,
  "obsolete" boolean DEFAULT false,
  PRIMARY KEY ("id"),
  CONSTRAINT "tag_tag_key" UNIQUE ("tag")
);

;
--
-- Table: correspondent_full_name
--
CREATE TABLE "correspondent_full_name" (
  "correspondent" integer NOT NULL,
  "full_name" text NOT NULL,
  "last_seen" timestamp DEFAULT current_timestamp NOT NULL,
  CONSTRAINT "correspondent_full_name_correspondent_full_name_idx" UNIQUE ("correspondent", "full_name")
);
CREATE INDEX "correspondent_full_name_idx_correspondent" on "correspondent_full_name" ("correspondent");
CREATE INDEX "correspondent_full_name_idx_full_name" on "correspondent_full_name" ("full_name");
CREATE INDEX "correspondent_full_name_idx_last_seen" on "correspondent_full_name" ("last_seen");

;
--
-- Table: maintainer
--
CREATE TABLE "maintainer" (
  "id" serial NOT NULL,
  "name" text NOT NULL,
  "correspondent" integer NOT NULL,
  "created" timestamp with time zone DEFAULT current_timestamp NOT NULL,
  "modified" timestamp with time zone DEFAULT current_timestamp NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "maintainer_name_idx" UNIQUE ("name")
);
CREATE INDEX "maintainer_idx_correspondent" on "maintainer" ("correspondent");

;
--
-- Table: message_refs
--
CREATE TABLE "message_refs" (
  "message" integer NOT NULL,
  "refs" integer NOT NULL,
  "inferred" boolean DEFAULT false,
  "primary_ref" boolean DEFAULT false,
  CONSTRAINT "message_refs_message_refs_idx" UNIQUE ("message", "refs")
);
CREATE INDEX "message_refs_idx_message" on "message_refs" ("message");
CREATE INDEX "message_refs_idx_refs" on "message_refs" ("refs");

;
--
-- Table: user_tag
--
CREATE TABLE "user_tag" (
  "id" serial NOT NULL,
  "tag" text NOT NULL,
  "correspondent" integer NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "user_tag_tag_correspondent" UNIQUE ("tag", "correspondent")
);
CREATE INDEX "user_tag_idx_correspondent" on "user_tag" ("correspondent");
CREATE INDEX "user_tag_correspondent" on "user_tag" ("correspondent");

;
--
-- Table: bug
--
CREATE TABLE "bug" (
  "id" integer NOT NULL,
  "creation" timestamp with time zone DEFAULT current_timestamp NOT NULL,
  "log_modified" timestamp with time zone DEFAULT current_timestamp NOT NULL,
  "last_modified" timestamp with time zone DEFAULT current_timestamp NOT NULL,
  "archived" boolean DEFAULT false NOT NULL,
  "unarchived" timestamp with time zone,
  "forwarded" text DEFAULT '' NOT NULL,
  "summary" text DEFAULT '' NOT NULL,
  "outlook" text DEFAULT '' NOT NULL,
  "subject" text NOT NULL,
  "severity" integer NOT NULL,
  "done" integer,
  "done_full" text DEFAULT '' NOT NULL,
  "owner" integer,
  "owner_full" text DEFAULT '' NOT NULL,
  "submitter" integer,
  "submitter_full" text DEFAULT '' NOT NULL,
  "unknown_packages" text DEFAULT '' NOT NULL,
  PRIMARY KEY ("id")
);
CREATE INDEX "bug_idx_done" on "bug" ("done");
CREATE INDEX "bug_idx_owner" on "bug" ("owner");
CREATE INDEX "bug_idx_severity" on "bug" ("severity");
CREATE INDEX "bug_idx_submitter" on "bug" ("submitter");
CREATE INDEX "bug_idxowner" on "bug" ("owner");
CREATE INDEX "bug_idxsubmitter" on "bug" ("submitter");
CREATE INDEX "bug_idxdone" on "bug" ("done");
CREATE INDEX "bug_idxforwarded" on "bug" ("forwarded");
CREATE INDEX "bug_idxlast_modified" on "bug" ("last_modified");
CREATE INDEX "bug_idxseverity" on "bug" ("severity");
CREATE INDEX "bug_idxcreation" on "bug" ("creation");
CREATE INDEX "bug_idxlog_modified" on "bug" ("log_modified");

;
--
-- Table: message_correspondent
--
CREATE TABLE "message_correspondent" (
  "message" integer NOT NULL,
  "correspondent" integer NOT NULL,
  "correspondent_type" character varying DEFAULT 'to' NOT NULL,
  CONSTRAINT "message_correspondent_message_correspondent_correspondent_t_idx" UNIQUE ("message", "correspondent", "correspondent_type")
);
CREATE INDEX "message_correspondent_idx_correspondent" on "message_correspondent" ("correspondent");
CREATE INDEX "message_correspondent_idx_message" on "message_correspondent" ("message");
CREATE INDEX "message_correspondent_idxcorrespondent" on "message_correspondent" ("correspondent");
CREATE INDEX "message_correspondent_idxmessage" on "message_correspondent" ("message");

;
--
-- Table: bug_blocks
--
CREATE TABLE "bug_blocks" (
  "id" serial NOT NULL,
  "bug" integer NOT NULL,
  "blocks" integer NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "bug_blocks_bug_id_blocks_idx" UNIQUE ("bug", "blocks")
);
CREATE INDEX "bug_blocks_idx_blocks" on "bug_blocks" ("blocks");
CREATE INDEX "bug_blocks_idx_bug" on "bug_blocks" ("bug");
CREATE INDEX "bug_blocks_bug_idx" on "bug_blocks" ("bug");
CREATE INDEX "bug_blocks_blocks_idx" on "bug_blocks" ("blocks");

;
--
-- Table: bug_merged
--
CREATE TABLE "bug_merged" (
  "id" serial NOT NULL,
  "bug" integer NOT NULL,
  "merged" integer NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "bug_merged_bug_id_merged_idx" UNIQUE ("bug", "merged")
);
CREATE INDEX "bug_merged_idx_bug" on "bug_merged" ("bug");
CREATE INDEX "bug_merged_idx_merged" on "bug_merged" ("merged");
CREATE INDEX "bug_merged_bug_idx" on "bug_merged" ("bug");
CREATE INDEX "bug_merged_merged_idx" on "bug_merged" ("merged");

;
--
-- Table: src_ver
--
CREATE TABLE "src_ver" (
  "id" serial NOT NULL,
  "src_pkg" integer NOT NULL,
  "ver" debversion NOT NULL,
  "maintainer" integer,
  "upload_date" timestamp with time zone DEFAULT current_timestamp NOT NULL,
  "based_on" integer,
  PRIMARY KEY ("id"),
  CONSTRAINT "src_ver_src_pkg_id_ver" UNIQUE ("src_pkg", "ver")
);
CREATE INDEX "src_ver_idx_based_on" on "src_ver" ("based_on");
CREATE INDEX "src_ver_idx_maintainer" on "src_ver" ("maintainer");
CREATE INDEX "src_ver_idx_src_pkg" on "src_ver" ("src_pkg");

;
--
-- Table: bug_affects_binpackage
--
CREATE TABLE "bug_affects_binpackage" (
  "bug" integer NOT NULL,
  "bin_pkg" integer NOT NULL,
  CONSTRAINT "bug_affects_binpackage_id_pkg" UNIQUE ("bug", "bin_pkg")
);
CREATE INDEX "bug_affects_binpackage_idx_bin_pkg" on "bug_affects_binpackage" ("bin_pkg");
CREATE INDEX "bug_affects_binpackage_idx_bug" on "bug_affects_binpackage" ("bug");

;
--
-- Table: bug_affects_srcpackage
--
CREATE TABLE "bug_affects_srcpackage" (
  "bug" integer NOT NULL,
  "src_pkg" integer NOT NULL,
  CONSTRAINT "bug_affects_srcpackage_id_pkg" UNIQUE ("bug", "src_pkg")
);
CREATE INDEX "bug_affects_srcpackage_idx_bug" on "bug_affects_srcpackage" ("bug");
CREATE INDEX "bug_affects_srcpackage_idx_src_pkg" on "bug_affects_srcpackage" ("src_pkg");

;
--
-- Table: bug_binpackage
--
CREATE TABLE "bug_binpackage" (
  "bug" integer NOT NULL,
  "bin_pkg" integer NOT NULL,
  CONSTRAINT "bug_binpackage_id_pkg" UNIQUE ("bug", "bin_pkg")
);
CREATE INDEX "bug_binpackage_idx_bin_pkg" on "bug_binpackage" ("bin_pkg");
CREATE INDEX "bug_binpackage_idx_bug" on "bug_binpackage" ("bug");
CREATE INDEX "bug_binpackage_bin_pkg_idx" on "bug_binpackage" ("bin_pkg");

;
--
-- Table: bug_message
--
CREATE TABLE "bug_message" (
  "bug" integer NOT NULL,
  "message" integer NOT NULL,
  "message_number" integer NOT NULL,
  "bug_log_offset" integer,
  "offset_valid" timestamp with time zone,
  CONSTRAINT "bug_message_bug_message_idx" UNIQUE ("bug", "message")
);
CREATE INDEX "bug_message_idx_bug" on "bug_message" ("bug");
CREATE INDEX "bug_message_idx_message" on "bug_message" ("message");
CREATE INDEX "bug_message_idx_bug_message_number" on "bug_message" ("bug", "message_number");

;
--
-- Table: bug_srcpackage
--
CREATE TABLE "bug_srcpackage" (
  "bug" integer NOT NULL,
  "src_pkg" integer NOT NULL,
  CONSTRAINT "bug_srcpackage_id_pkg" UNIQUE ("bug", "src_pkg")
);
CREATE INDEX "bug_srcpackage_idx_bug" on "bug_srcpackage" ("bug");
CREATE INDEX "bug_srcpackage_idx_src_pkg" on "bug_srcpackage" ("src_pkg");
CREATE INDEX "bug_srcpackage_src_pkg_idx" on "bug_srcpackage" ("src_pkg");

;
--
-- Table: bug_tag
--
CREATE TABLE "bug_tag" (
  "bug" integer NOT NULL,
  "tag" integer NOT NULL,
  CONSTRAINT "bug_tag_bug_tag" UNIQUE ("bug", "tag")
);
CREATE INDEX "bug_tag_idx_bug" on "bug_tag" ("bug");
CREATE INDEX "bug_tag_idx_tag" on "bug_tag" ("tag");
CREATE INDEX "bug_tag_tag" on "bug_tag" ("tag");

;
--
-- Table: bug_user_tag
--
CREATE TABLE "bug_user_tag" (
  "bug" integer NOT NULL,
  "user_tag" integer NOT NULL,
  CONSTRAINT "bug_user_tag_bug_tag" UNIQUE ("bug", "user_tag")
);
CREATE INDEX "bug_user_tag_idx_bug" on "bug_user_tag" ("bug");
CREATE INDEX "bug_user_tag_idx_user_tag" on "bug_user_tag" ("user_tag");
CREATE INDEX "bug_user_tag_tag" on "bug_user_tag" ("user_tag");

;
--
-- Table: bug_status_cache
--
CREATE TABLE "bug_status_cache" (
  "bug" integer NOT NULL,
  "suite" integer,
  "arch" integer,
  "status" character varying NOT NULL,
  "modified" timestamp with time zone DEFAULT current_timestamp NOT NULL,
  "asof" timestamp with time zone DEFAULT current_timestamp NOT NULL,
  CONSTRAINT "bug_status_cache_bug_suite_arch_idx" UNIQUE ("bug", "suite", "arch")
);
CREATE INDEX "bug_status_cache_idx_arch" on "bug_status_cache" ("arch");
CREATE INDEX "bug_status_cache_idx_bug" on "bug_status_cache" ("bug");
CREATE INDEX "bug_status_cache_idx_suite" on "bug_status_cache" ("suite");

;
--
-- Table: src_associations
--
CREATE TABLE "src_associations" (
  "id" serial NOT NULL,
  "suite" integer NOT NULL,
  "source" integer NOT NULL,
  "created" timestamp with time zone DEFAULT current_timestamp NOT NULL,
  "modified" timestamp with time zone DEFAULT current_timestamp NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "src_associations_source_suite" UNIQUE ("source", "suite")
);
CREATE INDEX "src_associations_idx_source" on "src_associations" ("source");
CREATE INDEX "src_associations_idx_suite" on "src_associations" ("suite");

;
--
-- Table: bin_ver
--
CREATE TABLE "bin_ver" (
  "id" serial NOT NULL,
  "bin_pkg" integer NOT NULL,
  "src_ver" integer NOT NULL,
  "arch" integer NOT NULL,
  "ver" debversion NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "bin_ver_bin_pkg_id_arch_idx" UNIQUE ("bin_pkg", "arch", "ver")
);
CREATE INDEX "bin_ver_idx_arch" on "bin_ver" ("arch");
CREATE INDEX "bin_ver_idx_bin_pkg" on "bin_ver" ("bin_pkg");
CREATE INDEX "bin_ver_idx_src_ver" on "bin_ver" ("src_ver");
CREATE INDEX "bin_ver_ver_id_idx" on "bin_ver" ("ver");
CREATE INDEX "bin_ver_bin_pkg_id_idx" on "bin_ver" ("bin_pkg");
CREATE INDEX "bin_ver_src_ver_id_idx" on "bin_ver" ("src_ver");
CREATE INDEX "bin_ver_src_ver_id_arch_idx" on "bin_ver" ("src_ver", "arch");

;
--
-- Table: bug_ver
--
CREATE TABLE "bug_ver" (
  "id" serial NOT NULL,
  "bug" integer NOT NULL,
  "ver_string" text,
  "src_pkg" integer,
  "src_ver" integer,
  "found" boolean DEFAULT true NOT NULL,
  "creation" timestamp with time zone DEFAULT current_timestamp NOT NULL,
  "last_modified" timestamp with time zone DEFAULT current_timestamp NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "bug_ver_bug_ver_string_found_idx" UNIQUE ("bug", "ver_string", "found")
);
CREATE INDEX "bug_ver_idx_bug" on "bug_ver" ("bug");
CREATE INDEX "bug_ver_idx_src_pkg" on "bug_ver" ("src_pkg");
CREATE INDEX "bug_ver_idx_src_ver" on "bug_ver" ("src_ver");
CREATE INDEX "bug_ver_src_pkg_id_idx" on "bug_ver" ("src_pkg");
CREATE INDEX "bug_ver_src_ver_id_idx" on "bug_ver" ("src_ver");
CREATE INDEX "bug_ver_src_pkg_id_src_ver_id_idx" on "bug_ver" ("src_pkg", "src_ver");

;
--
-- Table: bin_associations
--
CREATE TABLE "bin_associations" (
  "id" serial NOT NULL,
  "suite" integer NOT NULL,
  "bin" integer NOT NULL,
  "created" timestamp with time zone DEFAULT current_timestamp NOT NULL,
  "modified" timestamp with time zone DEFAULT current_timestamp NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "bin_associations_bin_suite" UNIQUE ("bin", "suite")
);
CREATE INDEX "bin_associations_idx_bin" on "bin_associations" ("bin");
CREATE INDEX "bin_associations_idx_suite" on "bin_associations" ("suite");

;
--
-- View: "binary_versions"
--
CREATE VIEW "binary_versions" ( "src_pkg", "src_ver", "bin_pkg", "arch", "bin_ver", "src_ver_based_on", "src_pkg_based_on" ) AS
    SELECT sp.pkg AS src_pkg, sv.ver AS src_ver, bp.pkg AS bin_pkg, a.arch AS arch, b.ver AS bin_ver,
svb.ver AS src_ver_based_on, spb.pkg AS src_pkg_based_on
FROM bin_ver b JOIN arch a ON b.arch = a.id
	              JOIN bin_pkg bp ON b.bin_pkg  = bp.id
               JOIN src_ver sv ON b.src_ver  = sv.id
               JOIN src_pkg sp ON sv.src_pkg = sp.id
               LEFT OUTER JOIN src_ver svb ON sv.based_on = svb.id
               LEFT OUTER JOIN src_pkg spb ON spb.id = svb.src_pkg;

;

;
--
-- View: "bug_package"
--
CREATE VIEW "bug_package" ( "bug", "pkg_id", "pkg_type", "package" ) AS
    SELECT b.bug,b.bin_pkg,'binary',bp.pkg FROM bug_binpackage b JOIN bin_pkg bp ON bp.id=b.bin_pkg UNION
       SELECT s.bug,s.src_pkg,'source',sp.pkg FROM bug_srcpackage s JOIN src_pkg sp ON sp.id=s.src_pkg;

;

;
--
-- Foreign Key Definitions
--

;
ALTER TABLE "src_pkg" ADD CONSTRAINT "src_pkg_fk_alias_of" FOREIGN KEY ("alias_of")
  REFERENCES "src_pkg" ("id") ON DELETE CASCADE ON UPDATE CASCADE;

;
ALTER TABLE "correspondent_full_name" ADD CONSTRAINT "correspondent_full_name_fk_correspondent" FOREIGN KEY ("correspondent")
  REFERENCES "correspondent" ("id") ON DELETE CASCADE ON UPDATE CASCADE;

;
ALTER TABLE "maintainer" ADD CONSTRAINT "maintainer_fk_correspondent" FOREIGN KEY ("correspondent")
  REFERENCES "correspondent" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION;

;
ALTER TABLE "message_refs" ADD CONSTRAINT "message_refs_fk_message" FOREIGN KEY ("message")
  REFERENCES "message" ("id") ON DELETE CASCADE ON UPDATE CASCADE;

;
ALTER TABLE "message_refs" ADD CONSTRAINT "message_refs_fk_refs" FOREIGN KEY ("refs")
  REFERENCES "message" ("id") ON DELETE CASCADE ON UPDATE CASCADE;

;
ALTER TABLE "user_tag" ADD CONSTRAINT "user_tag_fk_correspondent" FOREIGN KEY ("correspondent")
  REFERENCES "correspondent" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION;

;
ALTER TABLE "bug" ADD CONSTRAINT "bug_fk_done" FOREIGN KEY ("done")
  REFERENCES "correspondent" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION;

;
ALTER TABLE "bug" ADD CONSTRAINT "bug_fk_owner" FOREIGN KEY ("owner")
  REFERENCES "correspondent" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION;

;
ALTER TABLE "bug" ADD CONSTRAINT "bug_fk_severity" FOREIGN KEY ("severity")
  REFERENCES "severity" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION;

;
ALTER TABLE "bug" ADD CONSTRAINT "bug_fk_submitter" FOREIGN KEY ("submitter")
  REFERENCES "correspondent" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION;

;
ALTER TABLE "message_correspondent" ADD CONSTRAINT "message_correspondent_fk_correspondent" FOREIGN KEY ("correspondent")
  REFERENCES "correspondent" ("id") ON DELETE CASCADE ON UPDATE CASCADE;

;
ALTER TABLE "message_correspondent" ADD CONSTRAINT "message_correspondent_fk_message" FOREIGN KEY ("message")
  REFERENCES "message" ("id") ON DELETE CASCADE ON UPDATE CASCADE;

;
ALTER TABLE "bug_blocks" ADD CONSTRAINT "bug_blocks_fk_blocks" FOREIGN KEY ("blocks")
  REFERENCES "bug" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION;

;
ALTER TABLE "bug_blocks" ADD CONSTRAINT "bug_blocks_fk_bug" FOREIGN KEY ("bug")
  REFERENCES "bug" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION;

;
ALTER TABLE "bug_merged" ADD CONSTRAINT "bug_merged_fk_bug" FOREIGN KEY ("bug")
  REFERENCES "bug" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION;

;
ALTER TABLE "bug_merged" ADD CONSTRAINT "bug_merged_fk_merged" FOREIGN KEY ("merged")
  REFERENCES "bug" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION;

;
ALTER TABLE "src_ver" ADD CONSTRAINT "src_ver_fk_based_on" FOREIGN KEY ("based_on")
  REFERENCES "src_ver" ("id") ON DELETE CASCADE ON UPDATE CASCADE;

;
ALTER TABLE "src_ver" ADD CONSTRAINT "src_ver_fk_maintainer" FOREIGN KEY ("maintainer")
  REFERENCES "maintainer" ("id") ON DELETE SET NULL ON UPDATE CASCADE;

;
ALTER TABLE "src_ver" ADD CONSTRAINT "src_ver_fk_src_pkg" FOREIGN KEY ("src_pkg")
  REFERENCES "src_pkg" ("id") ON DELETE CASCADE ON UPDATE CASCADE;

;
ALTER TABLE "bug_affects_binpackage" ADD CONSTRAINT "bug_affects_binpackage_fk_bin_pkg" FOREIGN KEY ("bin_pkg")
  REFERENCES "bin_pkg" ("id") ON DELETE CASCADE ON UPDATE CASCADE;

;
ALTER TABLE "bug_affects_binpackage" ADD CONSTRAINT "bug_affects_binpackage_fk_bug" FOREIGN KEY ("bug")
  REFERENCES "bug" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION;

;
ALTER TABLE "bug_affects_srcpackage" ADD CONSTRAINT "bug_affects_srcpackage_fk_bug" FOREIGN KEY ("bug")
  REFERENCES "bug" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION;

;
ALTER TABLE "bug_affects_srcpackage" ADD CONSTRAINT "bug_affects_srcpackage_fk_src_pkg" FOREIGN KEY ("src_pkg")
  REFERENCES "src_pkg" ("id") ON DELETE CASCADE ON UPDATE CASCADE;

;
ALTER TABLE "bug_binpackage" ADD CONSTRAINT "bug_binpackage_fk_bin_pkg" FOREIGN KEY ("bin_pkg")
  REFERENCES "bin_pkg" ("id") ON DELETE CASCADE ON UPDATE CASCADE;

;
ALTER TABLE "bug_binpackage" ADD CONSTRAINT "bug_binpackage_fk_bug" FOREIGN KEY ("bug")
  REFERENCES "bug" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION;

;
ALTER TABLE "bug_message" ADD CONSTRAINT "bug_message_fk_bug" FOREIGN KEY ("bug")
  REFERENCES "bug" ("id") ON DELETE CASCADE ON UPDATE CASCADE;

;
ALTER TABLE "bug_message" ADD CONSTRAINT "bug_message_fk_message" FOREIGN KEY ("message")
  REFERENCES "message" ("id") ON DELETE CASCADE ON UPDATE CASCADE;

;
ALTER TABLE "bug_srcpackage" ADD CONSTRAINT "bug_srcpackage_fk_bug" FOREIGN KEY ("bug")
  REFERENCES "bug" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION;

;
ALTER TABLE "bug_srcpackage" ADD CONSTRAINT "bug_srcpackage_fk_src_pkg" FOREIGN KEY ("src_pkg")
  REFERENCES "src_pkg" ("id") ON DELETE CASCADE ON UPDATE CASCADE;

;
ALTER TABLE "bug_tag" ADD CONSTRAINT "bug_tag_fk_bug" FOREIGN KEY ("bug")
  REFERENCES "bug" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION;

;
ALTER TABLE "bug_tag" ADD CONSTRAINT "bug_tag_fk_tag" FOREIGN KEY ("tag")
  REFERENCES "tag" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION;

;
ALTER TABLE "bug_user_tag" ADD CONSTRAINT "bug_user_tag_fk_bug" FOREIGN KEY ("bug")
  REFERENCES "bug" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION;

;
ALTER TABLE "bug_user_tag" ADD CONSTRAINT "bug_user_tag_fk_user_tag" FOREIGN KEY ("user_tag")
  REFERENCES "user_tag" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION;

;
ALTER TABLE "bug_status_cache" ADD CONSTRAINT "bug_status_cache_fk_arch" FOREIGN KEY ("arch")
  REFERENCES "arch" ("id") ON DELETE CASCADE ON UPDATE CASCADE;

;
ALTER TABLE "bug_status_cache" ADD CONSTRAINT "bug_status_cache_fk_bug" FOREIGN KEY ("bug")
  REFERENCES "bug" ("id") ON DELETE CASCADE ON UPDATE CASCADE;

;
ALTER TABLE "bug_status_cache" ADD CONSTRAINT "bug_status_cache_fk_suite" FOREIGN KEY ("suite")
  REFERENCES "suite" ("id") ON DELETE CASCADE ON UPDATE CASCADE;

;
ALTER TABLE "src_associations" ADD CONSTRAINT "src_associations_fk_source" FOREIGN KEY ("source")
  REFERENCES "src_ver" ("id") ON DELETE CASCADE ON UPDATE CASCADE;

;
ALTER TABLE "src_associations" ADD CONSTRAINT "src_associations_fk_suite" FOREIGN KEY ("suite")
  REFERENCES "suite" ("id") ON DELETE CASCADE ON UPDATE CASCADE;

;
ALTER TABLE "bin_ver" ADD CONSTRAINT "bin_ver_fk_arch" FOREIGN KEY ("arch")
  REFERENCES "arch" ("id") ON DELETE CASCADE ON UPDATE CASCADE;

;
ALTER TABLE "bin_ver" ADD CONSTRAINT "bin_ver_fk_bin_pkg" FOREIGN KEY ("bin_pkg")
  REFERENCES "bin_pkg" ("id") ON DELETE CASCADE ON UPDATE CASCADE;

;
ALTER TABLE "bin_ver" ADD CONSTRAINT "bin_ver_fk_src_ver" FOREIGN KEY ("src_ver")
  REFERENCES "src_ver" ("id") ON DELETE CASCADE ON UPDATE CASCADE;

;
ALTER TABLE "bug_ver" ADD CONSTRAINT "bug_ver_fk_bug" FOREIGN KEY ("bug")
  REFERENCES "bug" ("id") ON DELETE RESTRICT ON UPDATE CASCADE;

;
ALTER TABLE "bug_ver" ADD CONSTRAINT "bug_ver_fk_src_pkg" FOREIGN KEY ("src_pkg")
  REFERENCES "src_pkg" ("id") ON DELETE SET NULL ON UPDATE CASCADE;

;
ALTER TABLE "bug_ver" ADD CONSTRAINT "bug_ver_fk_src_ver" FOREIGN KEY ("src_ver")
  REFERENCES "src_ver" ("id") ON DELETE SET NULL ON UPDATE CASCADE;

;
ALTER TABLE "bin_associations" ADD CONSTRAINT "bin_associations_fk_bin" FOREIGN KEY ("bin")
  REFERENCES "bin_ver" ("id") ON DELETE CASCADE ON UPDATE CASCADE;

;
ALTER TABLE "bin_associations" ADD CONSTRAINT "bin_associations_fk_suite" FOREIGN KEY ("suite")
  REFERENCES "suite" ("id") ON DELETE CASCADE ON UPDATE CASCADE;

;
