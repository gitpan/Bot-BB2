package Bot::BB2::TiedPluginHandle;

sub TIEHANDLE
{
	my( $class, $output_ref ) = @_;

	use Data::Dumper;
	warn "output_ref => ", Dumper $output_ref;

	return bless { output => $output_ref }, $class;
}

sub PRINT
{
	my( $self, @args ) = @_;

	$self->{output}->{stdout} .= join $", @args;

	return 1;
}

1;
