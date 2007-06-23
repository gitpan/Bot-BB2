package Bot::BB2::ConfigParser;
use strict;
use POE;
use Bot::BB2;
use Bot::BB2::PluginConfigParser;
use Config::General;

sub parse_and_create
{
	my( $class, $file ) = @_;

	my $conf = $class->parse_file( $file );
	my $bots = $conf->{bot};

	my @connections;
	while( my( $botname, $options ) = each %$bots )
	{
		for my $options ( ref $options eq 'ARRAY' ? @$options : $options )
		{
			$options->{botname} = $botname;
			push @connections, $options;
		}
	}

	my $plugin_opts = Bot::BB2::PluginConfigParser->parse_file( "plugin.conf" );
	my $bot = Bot::BB2->new( \@connections, $plugin_opts );

	$poe_kernel->run();
}

sub parse_file
{
	my( $class, $file ) = @_;
	
	return {
		Config::General->new(
			-ConfigFile => $file,
			-LowerCaseNames => 1,
			-UseApacheInclude => 1,
			-AutoTrue => 1
		)->getall
	};
}


1;
