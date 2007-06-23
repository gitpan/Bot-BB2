use IMDB;
use Storable qw/freeze thaw/;
use strict;

	my %commands = (
		quote => sub {
			my $obj = shift;
			my $i = 0;

			START:
			my $num_quotes = @{ $obj->{data}->{quotes} };
			my $quote = $obj->{data}->{quotes}->[rand $num_quotes];
			return if $i++ > 5;
			goto START if @$quote > 4;
			print join "\n", @$quote;
		},
		trivia => sub {
			my $obj = shift;
			my $num_trivias = @{ $obj->{data}->{trivia} };
			print $obj->{data}->{trivia}->[rand $num_trivias];
		},
	);

	for my $type ( qw/genre title summary/ )
	{
		$commands{$type}=sub{my$obj=shift;print $obj->{data}{$type}};
	}
	
	my $help_sub = sub {
		print "I currently support the following subcommands: ",join " ", keys %commands;
	};

{
	code => sub {
		my( $self, $said, $command, @title ) = @_;

		if( $command eq 'help' )
		{
			$help_sub->();
			return;
		}

		my $title = IMDB->normalize_title("@title");

		my $obj;
		if( heap()->{$title} )
		{
			$obj = thaw(heap()->{$title});
		}
		else
		{
#      print "Please wait while I fetch the necessary information from IMDb\n";
			$obj = IMDB->new( $title );
			heap()->{$title} = freeze($obj);
		}


		if( exists $commands{$command} )
		{
			$commands{$command}->($obj);
		}
		else
		{
			print "Sorry, $command is not valid";
			$help_sub->();
		}
	},
}
