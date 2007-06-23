use Bot::BB2::DaemonUtils;
use Data::Dumper;
use DB_File;

register(
	irc_privmsg => \&message,
	irc_public => \&message,
	irc_join => sub { change_channel( 'join', @_ ) },
	irc_part => sub { change_channel( 'part', @_ ) },
);

run();

tie my %heap, 'DB_File', 'seenserv.db' or die $!;

sub parse_hostnick
{
	my $nick = shift;
	
	my( $name, $host ) = split /\@/, $nick, 2;
	my( $nick, $user ) = split /!/, $name, 2;

	return( $nick, $user, $host );
}

sub message
{
	my( $event ) = @_;
	my $said = $event->{said};

	if( $said->{body} =~ /^\s*seen (\S+)/ )
	{
		my $nick = $1;

		if( my $seen = $heap{ $nick } ) 
		{
			my( $time, $phrase ) = split/\|/,$seen,2;
			reply( $said, "Seen at " . localtime($time) . ": $phrase" );
		}
		else
		{
			reply( $said, "Sorry, I haven't seen $nick" );
		}
	}
	else
	{
		$heap{ $said->{nick} } = time()."|<$said->{nick}> $said->{body}";
	}
}

sub change_channel
{
	my( $type, $event ) = @_;
	my @args = @{ $event->{args} };
	
	my( $nick ) = parse_hostnick( $args[0] );

	$heap{ $nick } = time."|$nick has ${type}ed $args[1]";
	
}

