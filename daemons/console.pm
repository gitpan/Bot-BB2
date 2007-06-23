use Bot::BB2::DaemonUtils;
use POE;
use POE::Wheel::SocketFactory;
use POE::Filter::Line;
use POE::Driver::SysRW;
use Socket;

register(
	none => sub {},
);

test();
run();

my $s;
sub test
{
	warn "sesson starting\n";
	$s = POE::Session->create(
		inline_states => {
			_start => sub {
				my( $heap ) = @_[HEAP];
				warn "Creating socketfactory on 10100\n";
				$heap->{wheel} = POE::Wheel::SocketFactory->new(
					BindAddress => '127.0.0.1',
					BindPort => '10100',
					SocketDomain => AF_INET(),
					SocketType => SOCK_STREAM(),
					SocketProtocol => 'tcp',
					ListenQueue => 50,
					Reuse => 'on',

					SuccessEvent => 'win',
					FailureEvent => 'lose',
				);
			},

			lose => sub {
				warn "LOSING: @_[ARG0..ARG3]\n";
			},

			win => sub {
				my( $heap, $socket ) = @_[HEAP,ARG0];
				warn "Got connection: $socket\n";
				my $wheel = POE::Wheel::ReadWrite->new(
					Handle => $socket,
					Driver => POE::Driver::SysRW->new,
					Filter => POE::Filter::Line->new,

					InputEvent => 'hatred',
				);
				push @{$heap->{flag}}, $wheel;
			},

			hatred => sub {
				my( $heap, $text ) = @_[HEAP,ARG0];
				my( $channel, $message ) = split(/:/, $text, 2);

				say( { channel => $channel, body => $message, poco_irc => "irc.freenode.org" } );
			},

			_stop => sub { warn "OMG I AM STOPPING!" },
		}
	);
}
