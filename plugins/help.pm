{
	code => sub {
		my( $self, $said, @args ) = @_;

		print "Available Plugins: ", join " ", $self->plugins_available;
	},
}
