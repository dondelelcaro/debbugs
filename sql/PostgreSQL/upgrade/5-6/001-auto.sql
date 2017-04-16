-- Convert schema 'sql/_source/deploy/5/001-auto.yml' to 'sql/_source/deploy/6/001-auto.yml':;

;
BEGIN;

;
CREATE INDEX bin_ver_ver_id_idx on bin_ver (ver);

;
CREATE INDEX bin_ver_src_ver_id_arch_idx on bin_ver (src_ver, arch);

;
CREATE INDEX bug_idxforwarded on bug (forwarded);

;
CREATE INDEX bug_idxlast_modified on bug (last_modified);

;
CREATE INDEX bug_idxcreation on bug (creation);

;
CREATE INDEX bug_idxlog_modified on bug (log_modified);

;
CREATE INDEX bug_message_idx_bug_message_number on bug_message (bug, message_number);

;
CREATE INDEX bug_ver_src_pkg_id_src_ver_id_idx on bug_ver (src_pkg, src_ver);

;
CREATE INDEX message_correspondent_idxmessage on correspondent_full_name (message);

;
CREATE INDEX message_msgid_idx on message (msgid);

;
CREATE INDEX message_subject_idx on message (subject);

;
CREATE INDEX severity_ordering_idx on severity (ordering);

;
CREATE INDEX src_pkg_pkg on src_pkg (pkg);

;

COMMIT;

