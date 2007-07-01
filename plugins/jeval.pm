use POE::Session;
use POE::Wheel::Run;
use Data::Dumper qw/Dumper/;
use Jplugin;
use strict;

{
	code => sub {
		my( $self, $said, @args ) = @_;

		my $stdout;
		my $stderr;

		my $input_subref = sub { 
			my $ret = Jplugin::jplugin( "@args" );
			print "\n";

			if( $@ ) { print "ERROR: $@\n" }
		};

		my $output_subref = sub {
			my( $stderr, $stdout ) = @_;
			
			print +(substr $stdout,0,240)." ".(substr $stderr,0,250)."\n";
		};

		wheel_execute( $input_subref, $output_subref );

		warn "after declared session";
	}
}

