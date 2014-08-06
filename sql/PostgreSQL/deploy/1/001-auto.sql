-- 
-- Created by SQL::Translator::Producer::PostgreSQL
-- Created on Wed Aug  6 09:18:36 2014
-- 
;
--
-- Table: arch.
--
CREATE TABLE "arch" (
  "id" serial NOT NULL,
  "arch" text NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "arch_arch_key" UNIQUE ("arch")
);

;
--
-- Table: bin_pkg.
--
CREATE TABLE "bin_pkg" (
  "id" serial NOT NULL,
  "pkg" text NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "bin_pkg_pkg_key" UNIQUE ("pkg")
);

;
--
-- Table: binary_versions.
--
CREATE TABLE "binary_versions" (
  "src_pkg" text,
  "src_ver" debversion,
  "bin_pkg" text,
  "arch" text,
  "bin_ver" debversion,
  "src_ver_based_on" debversion,
  "src_pkg_based_on" text
);

;
--
-- Table: bug_package.
--
CREATE TABLE "bug_package" (
  "bug" integer,
  "pkg_id" integer,
  "pkg_type" text,
  "package" text
);

;
--
-- Table: column_comments.
--
CREATE TABLE "column_comments" (
  "table_name" text NOT NULL,
  "column_name" text NOT NULL,
  "comment_text" text NOT NULL,
  CONSTRAINT "column_comments_table_name_column_name_idx" UNIQUE ("table_name", "column_name")
);

;
--
-- Table: correspondent.
--
CREATE TABLE "correspondent" (
  "id" serial NOT NULL,
  "addr" text NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "correspondent_addr_idx" UNIQUE ("addr")
);

;
--
-- Table: dbix_class_deploymenthandler_versions.
--
CREATE TABLE "dbix_class_deploymenthandler_versions" (
  "id" serial NOT NULL,
  "version" character varying(50) NOT NULL,
  "ddl" text,
  "upgrade_sql" text,
  PRIMARY KEY ("id"),
  CONSTRAINT "dbix_class_deploymenthandler_versions_version" UNIQUE ("version")
);

;
--
-- Table: message.
--
CREATE TABLE "message" (
  "id" serial NOT NULL,
  "msgid" text,
  "from_complete" text,
  "from_addr" text,
  "to_complete" text,
  "to_addr" text,
  "subject" text DEFAULT '' NOT NULL,
  "sent_date" timestamp with time zone,
  "refs" text DEFAULT '' NOT NULL,
  "spam_score" double precision,
  "is_spam" boolean DEFAULT false,
  PRIMARY KEY ("id")
);

;
--
-- Table: severity.
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

;
--
-- Table: src_pkg.
--
CREATE TABLE "src_pkg" (
  "id" serial NOT NULL,
  "pkg" text NOT NULL,
  "pseduopkg" boolean DEFAULT false,
  "alias_of" integer,
  "creation" timestamp with time zone DEFAULT current_timestamp,
  "disabled" timestamp with time zone,
  "last_modified" timestamp with time zone DEFAULT current_timestamp,
  "obsolete" boolean DEFAULT false,
  PRIMARY KEY ("id"),
  CONSTRAINT "src_pkg_pkg_disabled" UNIQUE ("pkg", "disabled")
);
CREATE INDEX "src_pkg_idx_alias_of" on "src_pkg" ("alias_of");

;
--
-- Table: suite.
--
CREATE TABLE "suite" (
  "id" serial NOT NULL,
  "suite_name" text NOT NULL,
  "version" text,
  "codename" text,
  "active" boolean DEFAULT true,
  PRIMARY KEY ("id"),
  CONSTRAINT "suite_suite_name_key" UNIQUE ("suite_name")
);

;
--
-- Table: table_comments.
--
CREATE TABLE "table_comments" (
  "table_name" text NOT NULL,
  "comment_text" text NOT NULL,
  CONSTRAINT "table_comments_table_name_key" UNIQUE ("table_name")
);

;
--
-- Table: tag.
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
-- Table: correspondent_full_name.
--
CREATE TABLE "correspondent_full_name" (
  "id" serial NOT NULL,
  "correspondent" integer NOT NULL,
  "full_name" text NOT NULL,
  "last_seen" timestamp DEFAULT current_timestamp NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "correspondent_full_name_correspondent_full_name_idx" UNIQUE ("correspondent", "full_name")
);
CREATE INDEX "correspondent_full_name_idx_correspondent" on "correspondent_full_name" ("correspondent");

;
--
-- Table: maintainer.
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
-- Table: message_refs.
--
CREATE TABLE "message_refs" (
  "id" serial NOT NULL,
  "message" integer NOT NULL,
  "refs" integer NOT NULL,
  "inferred" boolean DEFAULT false,
  "primary_ref" boolean DEFAULT false,
  PRIMARY KEY ("id"),
  CONSTRAINT "message_refs_message_refs_idx" UNIQUE ("message", "refs")
);
CREATE INDEX "message_refs_idx_message" on "message_refs" ("message");
CREATE INDEX "message_refs_idx_refs" on "message_refs" ("refs");

;
--
-- Table: bug.
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

;
--
-- Table: message_correspondent.
--
CREATE TABLE "message_correspondent" (
  "id" serial NOT NULL,
  "message" integer NOT NULL,
  "correspondent" integer NOT NULL,
  "correspondent_type" character varying DEFAULT 'to' NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "message_correspondent_message_correspondent_correspondent_t_idx" UNIQUE ("message", "correspondent", "correspondent_type")
);
CREATE INDEX "message_correspondent_idx_correspondent" on "message_correspondent" ("correspondent");
CREATE INDEX "message_correspondent_idx_message" on "message_correspondent" ("message");

;
--
-- Table: bug_blocks.
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

;
--
-- Table: bug_merged.
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

;
--
-- Table: src_ver.
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
-- Table: bug_binpackage.
--
CREATE TABLE "bug_binpackage" (
  "id" serial NOT NULL,
  "bug" integer NOT NULL,
  "bin_pkg" integer NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "bug_binpackage_id_pkg" UNIQUE ("bug", "bin_pkg")
);
CREATE INDEX "bug_binpackage_idx_bin_pkg" on "bug_binpackage" ("bin_pkg");
CREATE INDEX "bug_binpackage_idx_bug" on "bug_binpackage" ("bug");

;
--
-- Table: bug_message.
--
CREATE TABLE "bug_message" (
  "id" serial NOT NULL,
  "bug" integer NOT NULL,
  "message" integer NOT NULL,
  "message_number" integer NOT NULL,
  "bug_log_offset" integer,
  "offset_valid" timestamp with time zone,
  PRIMARY KEY ("id"),
  CONSTRAINT "bug_message_bug_message_idx" UNIQUE ("bug", "message")
);
CREATE INDEX "bug_message_idx_bug" on "bug_message" ("bug");
CREATE INDEX "bug_message_idx_message" on "bug_message" ("message");

;
--
-- Table: bug_srcpackage.
--
CREATE TABLE "bug_srcpackage" (
  "id" serial NOT NULL,
  "bug" integer NOT NULL,
  "src_pkg" integer NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "bug_srcpackage_id_pkg" UNIQUE ("bug", "src_pkg")
);
CREATE INDEX "bug_srcpackage_idx_bug" on "bug_srcpackage" ("bug");
CREATE INDEX "bug_srcpackage_idx_src_pkg" on "bug_srcpackage" ("src_pkg");

;
--
-- Table: bug_tag.
--
CREATE TABLE "bug_tag" (
  "id" serial NOT NULL,
  "bug" integer NOT NULL,
  "tag" integer NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "bug_tag_bug_tag" UNIQUE ("bug", "tag")
);
CREATE INDEX "bug_tag_idx_bug" on "bug_tag" ("bug");
CREATE INDEX "bug_tag_idx_tag" on "bug_tag" ("tag");

;
--
-- Table: bug_status_cache.
--
CREATE TABLE "bug_status_cache" (
  "id" serial NOT NULL,
  "bug" integer NOT NULL,
  "suite" integer,
  "arch" integer,
  "status" character varying NOT NULL,
  "modified" timestamp with time zone DEFAULT current_timestamp NOT NULL,
  "asof" timestamp with time zone DEFAULT current_timestamp NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "bug_status_cache_bug_suite_arch_idx" UNIQUE ("bug", "suite", "arch")
);
CREATE INDEX "bug_status_cache_idx_arch" on "bug_status_cache" ("arch");
CREATE INDEX "bug_status_cache_idx_bug" on "bug_status_cache" ("bug");
CREATE INDEX "bug_status_cache_idx_suite" on "bug_status_cache" ("suite");

;
--
-- Table: src_associations.
--
CREATE TABLE "src_associations" (
  "id" serial NOT NULL,
  "suite" integer NOT NULL,
  "source" integer NOT NULL,
  "created" timestamp with time zone DEFAULT current_timestamp NOT NULL,
  "modified" timestamp with time zone DEFAULT current_timestamp NOT NULL,
  PRIMARY KEY ("id")
);
CREATE INDEX "src_associations_idx_source" on "src_associations" ("source");
CREATE INDEX "src_associations_idx_suite" on "src_associations" ("suite");

;
--
-- Table: bin_ver.
--
CREATE TABLE "bin_ver" (
  "id" serial NOT NULL,
  "bin_pkg" integer NOT NULL,
  "src_ver" integer NOT NULL,
  "arch" integer NOT NULL,
  "ver" debversion NOT NULL,
  PRIMARY KEY ("id")
);
CREATE INDEX "bin_ver_idx_arch" on "bin_ver" ("arch");
CREATE INDEX "bin_ver_idx_bin_pkg" on "bin_ver" ("bin_pkg");
CREATE INDEX "bin_ver_idx_src_ver" on "bin_ver" ("src_ver");

;
--
-- Table: bug_ver.
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

;
--
-- Table: bin_associations.
--
CREATE TABLE "bin_associations" (
  "id" serial NOT NULL,
  "suite" integer NOT NULL,
  "bin" integer NOT NULL,
  "created" timestamp with time zone DEFAULT current_timestamp NOT NULL,
  "modified" timestamp with time zone DEFAULT current_timestamp NOT NULL,
  PRIMARY KEY ("id")
);
CREATE INDEX "bin_associations_idx_bin" on "bin_associations" ("bin");
CREATE INDEX "bin_associations_idx_suite" on "bin_associations" ("suite");

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
ALTER TABLE "bug_binpackage" ADD CONSTRAINT "bug_binpackage_fk_bin_pkg" FOREIGN KEY ("bin_pkg")
  REFERENCES "bin_pkg" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION;

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
