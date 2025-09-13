# -*- mode: cperl;-*-

use Test::More tests => 5;

use warnings;
use strict;

# Here, we're going to shoot messages through a set of things that can
# happen.

# First, we're going to send mesages to receive.
# To do so, we'll first send a message to submit,
# then send messages to the newly created bugnumber.

use IO::File;
use File::Temp     qw(tempdir);
use Cwd            qw(getcwd);
use Debbugs::MIME  qw(create_mime_message);
use File::Basename qw(dirname basename);

# The test functions are placed here to make things easier
use lib         qw(t/lib);
use DebbugsTest qw(:all);
use Data::Dumper;
use Encode qw(decode encode);

# HTTP::Server:::Simple defines a SIG{CHLD} handler that breaks system; undef it here.
$SIG{CHLD} = sub { };
my %config = create_debbugs_configuration( additional_debbugs_config =>
      qq(\$gCcAllMailsToAddr='cc_addr\@example.com';\n) );

my $sendmail_dir = $config{sendmail_dir};
my $spool_dir    = $config{spool_dir};
my $config_dir   = $config{config_dir};

# We're going to use create mime message to create these messages, and
# then just send them to receive.

send_message(
    to      => 'submit@bugs.something',
    headers => [
        To      => 'submit@bugs.something',
        From    => 'foo@bugs.something',
        Subject => 'Submiting a bug',
    ],
    body => <<EOF ) or fail('Unable to send message');
Package: foo
Severity: normal

This is a silly bug
EOF

# next, we check to see that (at least) the proper messages have been
# sent out. 1) ack to submitter 2) mail to maintainer 3) mail to cc

# This keeps track of the previous size of the sendmail directory
my $SD_SIZE = 0;
$SD_SIZE =
  num_messages_sent( $SD_SIZE, 2, $sendmail_dir,
    'submit messages appear to have been sent out properly',
  );

# Validate that a message has been sent to cc_addr@example.com
ok(
    system( 'sh', '-c',
            'find '
          . $sendmail_dir
          . q( -type f | xargs grep -q "called with:.*'cc_addr@example.com'") )
      == 0,
    'Message sent to cc_addr@example.com'
);

# now send a message to the bug

send_message(
    to      => '1@bugs.something',
    headers => [
        To      => '1@bugs.something',
        From    => 'foo@bugs.something',
        Subject => 'Sending a message to a bug',
    ],
    body => <<'EOF' ) or fail('sending message to 1@bugs.someting failed');
Package: foo
Severity: normal
X-Debbugs-Cc: xdebbugscc@example.com

This is a silly bug
EOF

$SD_SIZE =
  num_messages_sent( $SD_SIZE, 2, $sendmail_dir,
    '1@bugs.something messages appear to have been sent out properly' );

# Validate that a message has been sent to xdebbugscc@example.com
ok(
    system( 'sh', '-c',
            'find '
          . $sendmail_dir
          . q( -type f | xargs grep -q "called with:.*'xdebbugscc@example.com'") )
      == 0,
    'Message sent to xdebbugscc@example.com'
);


# just check to see that control doesn't explode
send_message(
    to      => 'control@bugs.something',
    headers => [
        To      => 'control@bugs.something',
        From    => 'foo@bugs.something',
        Subject => 'Munging a bug',
    ],
    body => <<EOF ) or fail 'message to control@bugs.something failed';
severity 1 wishlist
retitle 1 new title
thanks
EOF

$SD_SIZE =
  num_messages_sent( $SD_SIZE, 1, $sendmail_dir,
    'control@bugs.something messages appear to have been sent out properly' );

