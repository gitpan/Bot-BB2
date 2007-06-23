{
	code => sub {
		my( $self, $said, @args ) = @_;

		self_cmd( "part_channels", $said->{poco_irc}, @args );
	},
}
