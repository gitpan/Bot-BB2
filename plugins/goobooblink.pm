=head1 NAME

Goobooblink

=head1 DESCRIPTION

Provides a direct flash-free link to Gooboob videos when it spots them
in a channel via L<WebService::YouTube::Util>, the resulting file can
usually be played with vanilla mplayer without propritery plugins.

=cut

use strict;

use WWW::Mechanize;
use WWW::Shorten qw< Metamark >;
use HTML::TreeBuilder;

use WebService::YouTube::Util;
use WebService::YouTube::Video;

my %boobcache; # id => [ title, link ] cache

{
    code      => sub {
        my ($self, $said, $uri) = @_;

        # Get the ID
        my ($id) = $uri =~ m<youtube\.com/(?:watch\?v=|v/)(\S+)>;
        return unless $id;

        my ($title, $smallboob);

        # Get from cache if we have it
        if ( $boobcache{ $id } ) {
            ($title, $smallboob) = @{ $boobcache{ $id } };
            goto sayboobs; # jmp around!
        }

        # Get the <title> of the video without the gooboob api
        my $mech = WWW::Mechanize->new;
        my $boobs = $mech->get( sprintf q<http://www.youtube.com/watch?v=%s>, $id );

        # Construct a HTML tree to get <title>
        my $tree = HTML::TreeBuilder->new_from_content( $boobs->content );
        my $cont = $tree->look_down( _tag => 'title' )->attr( '_content' );
        $title = $cont->[ 0 ]; # Just get it from the first (and only) element
        $title =~ s/^YouTube - //; # Remove redundant info from <title>

        # Get a direct link to the video
        my $video = WebService::YouTube::Video->new( { id => $id } );
        my $booburi = WebService::YouTube::Util->get_video_uri( $video );

        # The direct link is too long, shorten it!
        $smallboob = makeashorterlink( $booburi );

        # Insert into cache for later
        $boobcache{ $id } = [ $title => $smallboob ];

      sayboobs:
        print "[ $title ] - $smallboob";
    }
}
