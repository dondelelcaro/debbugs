sub upgrade {
    my $s = shift;

    $s->prepare_execute(<<'SQL');
ALTER TABLE correspondent_full_name RENAME TO correspondent_full_name_old;

CREATE TABLE correspondent_full_name(
correspondent INT NOT NULL REFERENCES correspondent ON DELETE CASCADE ON UPDATE CASCADE,
full_addr TEXT NOT NULL,
"name" TEXT NOT NULL,
last_seen TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX ON correspondent_full_name(correspondent,full_addr);
CREATE INDEX ON correspondent_full_name(full_addr);

INSERT INTO correspondent_full_name
SELECT cfn.correspondent,CONCAT(cfn.full_name,' <',c.addr,'>') AS full_addr,
cfn.full_name, cfn.last_seen
FROM correspondent_full_name_old cfn
JOIN correspondent c ON cfn.correspondent=c.id;

SQL
}

1;
