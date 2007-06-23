use POE::Session;
use POE::Wheel::Run;
use Data::Dumper qw/Dumper/;
use Jplugin;
use strict;

my $LINE_MATCHER = qr/^\s*jeval:\s*(.+)/;

my $evaluator = sub {
	my( $self, $said, @args ) = @_;
	#$poe_kernel->stop();

	if( not @args ) 
	{
		if( $said->{body} =~ $LINE_MATCHER )
		{
			@args = $1;
		}
		else
		{
			return;
		}
	}

	warn "PLUGIN-EVAL: @args\n";

	my $stdout;
	my $stderr;

	my $input_subref = sub { 
		my $ret = Jplugin::jplugin( "@args" );

		if( ref $ret )
		{
			local $Data::Dumper::Terse = 1;
			local $Data::Dumper::Quotekeys = 0;
			local $Data::Dumper::Indent = 0;

			my $out = Dumper( $ret );
			print "$out\n";
		}
		else
		{
			print "$ret\n"; 
		}
		if( $@ ) { print "ERROR: $@\n" }
	};

	my $output_subref = sub {
		my( $stderr, $stdout ) = @_;
		
#    print "OUTPUT-- $stdout $stderr\n";
		print "$said->{nick}:" . (substr $stdout,0,240)." ".(substr $stderr,0,250)."\n";
	};

	wheel_execute( $input_subref, $output_subref );

	warn "after declared session";



};

{
	privmsg => sub {
		my( $self, $said ) = @_;

		if( $said->{body} =~ $LINE_MATCHER )
		{
			return 1;
		}

		return;
	},
	code => $evaluator,
}
