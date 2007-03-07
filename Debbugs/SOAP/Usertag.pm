package Debbugs::SOAP::Usertag;

use Debbugs::User;

sub get_usertag {
    my ($class, $email, $tag) = @_;
    my %ut = ();
    Debbugs::User::read_usertags(\%ut, $email);
    if (defined($tag) and $tag ne "") {
	# Remove unwanted tags
	foreach (keys %ut) {
	    delete $ut{$_} unless $_ eq $tag;
	}
    }
    return \%ut;
}

1;
