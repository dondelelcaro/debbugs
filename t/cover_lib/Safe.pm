# this is a tiny module which basically provides a fake safe for use with Devel::Cover
package Safe;

sub new {
    my $class = shift;
    my $self = {root => 'fakeSafe'};
    bless ($self,$class);
    return $self;
}

sub permit {
}

sub reval {
    my ($self,$code) = @_;
    eval "package $self->{root}; $code";
}

sub root {
    my ($self) = @_;
    return($self->{root});
}

sub varglob {
    my ($self,$var) = @_;
    no strict 'refs';
    no warnings 'once';
    return *{$self->{root}."::$var"};
}

1;
