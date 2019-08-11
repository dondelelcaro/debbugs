package Debbugs::Mojo;

use Mojo::Base 'Mojolicious';

sub startup {
  my $self = shift;

  $self->plugin('Debbugs::Mojo::Plugin::DBI');
  $self->plugin('Debbugs::Mojo::Plugin::Xslate');
  my $r = $self->routes;
  $r->namespaces(['Debbugs::Mojo::Controller']);
  $r->add_type(bug => qr/\d+/);
  $r->add_type(package => qr/[a-z0-9][a-z0-9\.+-]+/);
  $r->get('/<bug:bug>')->to('Bug#show')->name('show_bug');
  $r->get('/bug/<bug:bug>')->to('Bug#show')->name('show_bug');
  $r->get('/<package:package>')->to('Package#show')->name('show_package');
  $r->get('/package/<package:package>')->to('Package#show')->name('show_package');
  $r->get('/' => sub {
	      my $c = shift;
	      $c->render(text => 'Mojolicious rocks');
	  });
}

1;

