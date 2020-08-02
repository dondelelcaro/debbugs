sub upgrade {
    my $s = shift;
print STDERR "Foo";
    $s->prepare_execute(<<'SQL');
SELECT * FROM db_version;
SQL
}

1;
