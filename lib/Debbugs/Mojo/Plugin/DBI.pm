package Debbugs::Mojo::Plugin::DBI;

use Mojo::Base 'Mojolicious::Plugin';

use Debbugs::DB;
use Debbugs::Config qw(:config);

sub register {
    my ($self,$app) = @_;

    my $helper = sub {
	return Debbugs::DB->connect($config{debbugs_db});
    };
    $app->helper('db', $helper);
    return $self;
}

1;

