use XML::RAI;
use LWP::Simple;
use HTML::Entities qw/decode_entities/;
use strict;

#Evil hack because XML::SAX relies on having this entry to find its parsers but BB2 clears %INC randomly.
my $xml_sax_loc = $INC{'XML/SAX.pm'};

{
	code => sub {
		my( $self, $said, $feed ) = @_;
		$INC{'XML/SAX.pm'} = $xml_sax_loc;

		my $rss = get( $feed );
		if( not defined $rss and not length $rss ) { print "Error fetching feed:$feed"; return }

		my $rai = XML::RAI->parse_string( $rss );

		my @items = @{ $rai->items };
		$#items = 4 if $#items > 4;
#    for( @items )
#    {
#      print decode_entities($_->title), ", ";
#    }
		print join ", ", map decode_entities($_->title), @items;
	}
}

