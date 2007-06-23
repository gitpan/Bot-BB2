{
	code => sub {
		my( $self, $said, @args ) = @_;

		self_cmd( "join_channels", $said->{poco_irc}, @args );

		print "Attempting to join @args";
	}
}
