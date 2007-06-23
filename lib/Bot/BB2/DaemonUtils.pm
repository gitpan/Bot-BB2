package Bot::BB2::DaemonUtils;
use POE::Filter::Reference;
use POE::Driver::SysRW;
use POE::Wheel::ReadWrite;
use POE::Session;
use POE;
use IO::Socket::INET;
use Data::Dumper;
use strict;

use base 'Exporter';

our @EXPORT = qw/register say reply reply_with_remainder run enable_output_parsing disable_output_parsing/;
my $session;

$SIG{__WARN__} = sub { warn "DAEMON-$$: @_"; };

sub run { POE::Kernel->run }

our $OUTPUT_PARSING = 0;
sub enable_output_parsing
{
	$OUTPUT_PARSING = 1;
}

sub disable_output_parsing
{
	$OUTPUT_PARSING = 0;
}

sub say
{
	my( $said ) = @_;

	my $struct = {
		type => 'output',
		said => $said,
		output_parsing => $OUTPUT_PARSING,
	};
		
	$session->get_heap->{wheel}->put( [$struct] );
}

sub reply
{
	my( $said, $reply ) = @_;
	my $new_said = { %$said, body => $reply };

	say( $new_said );
}

sub reply_with_remainder
{
	my( $said, $reply, @remainder ) = @_;

	my $new_said = { %$said, body => $reply };
	$new_said->{commands_to_parse} = "@remainder";

	say( $new_said );
}

sub register
{
	my( %states ) = @_;

	warn "Daemon registering\n";
	unless( $ENV{_BB2_DAEMON_PORT} )
	{
		die "Error, need ENV _BB2_DAEMON_PORT set to a valid port to start.\n";
	}

	$session = POE::Session->create(
		inline_states => { 
			_start => \&_start,
			input => \&input,
			error => \&error,
		},
		args => [ @_ ],
		heap => { states => {%states} },
	);
}

sub _start
{
	my( $heap, %events ) = @_[HEAP, ARG0..$#_];

	warn "Attempting to open a child->parent socket on $ENV{_BB2_DAEMON_PORT}\n";

	my $socket = IO::Socket::INET->new(
		PeerAddr => '127.0.0.1',
		PeerPort => $ENV{_BB2_DAEMON_PORT},
		Proto => 'tcp',
		Type => SOCK_STREAM(),
		ReuseAddr => 'yes',
	) or die "Error, couldn't create socket to parent, $@";

	$heap->{wheel} = POE::Wheel::ReadWrite->new(
		Handle => $socket,
		Driver => POE::Driver::SysRW->new,
		Filter => POE::Filter::Reference->new,
		InputEvent => 'input',
		ErrorEvent => 'error',
	) or warn "Wheel error: $@ $!\n";
	
	my $file_name = determine_last_caller();
	for( keys %events )
	{
		my $struct = { type => 'register', event => $_, name => $file_name };
		warn "Sending register event to parent for: $_\n";
		$heap->{wheel}->put( [ $struct ] );
	}
}

sub error 
{
	my( $operation, $errnum, $errstr ) = @_[ARG0..ARG2];

	warn "Daemon got error attempting $operation-$errnum:$errstr";
	exit;
}

sub input
{
	my( $heap, $records ) = @_[HEAP,ARG0];
#  warn "Got rec: ",  Dumper ($records),"\n";
	if( not ref $records eq 'ARRAY' ) { warn "Error, expected arrayref as input, got $records"; return; }

	for my $rec ( @$records )
	{
		if( not ref $rec or ref $rec ne 'HASH' ) { warn "Error, must have hashref for input, got $rec"; return; }

		if( $rec->{type} eq 'event' )
		{
			if( my $coderef = $heap->{states}->{ $rec->{event} } )
			{
				$coderef->( $rec );
			}
		}
	}
}

sub output
{
	my( $heap, $data ) = @_[HEAP,ARG0];
	$heap->{wheel}->put( $data );
}

sub determine_last_caller
{
	my $i = 0;

	while( defined caller($i) )
	{
		$i++;
	}

	return( (caller($i-1))[1] );
}

1;
