package RottenTomatoes;
use URI::Escape qw/uri_escape/;
use URI;
use LWP::Simple;
use HTML::TreeBuilder;

sub normalize_title
{
	my( $self, $title ) = @_;
	$title = lc $title;
	$title =~ s/[^\w ]//g;
	return $title;
}

sub search
{
	my( $self, $title ) = @_;
	$title = $self->normalize_title($title);
	warn "Searching for $title\n";
	$title = uri_escape($title);
	my $uri = "http://www.rottentomatoes.com/search/full_search.php?search=$title";
	warn "Search uri: $title\n";

	my $search_html = get($uri);
	my $tree = HTML::TreeBuilder->new;
	$tree->parse($search_html);
	$tree->eof;

	my $first_link = $tree->look_down( _tag => 'a', class => 'movie-link' );

	my $movie_uri = URI->new_abs( $first_link->attr('href'), $uri );
	warn "movie_uri: $movie_uri\n";

	my $movie_html = get($movie_uri);
	my $movie_tree = HTML::TreeBuilder->new;
	$movie_tree->parse($movie_html);
	$movie_tree->eof;

	return ( $first_link->as_text, $movie_tree );
}


sub rating_and_blurb
{
	my( $self, $search_string ) = @_;

	my( $title, $tree ) = $self->search( $search_string );

	my $score;
	if( $tree->as_HTML =~ /Currently, there are not enough Tomatometer critic reviews/ )
	{
		$score = "Not enough ratings";
	}
	else
	{
		$score = $tree->look_down( id => 'critics_tomatometer_score_txt' )->as_text;
	}
		

	my @blurbs = $tree->look_down( class => 'reviews_quote_content' );

	my $blurb;
	if( @blurbs ) { $blurb = $blurbs[rand@blurbs]->as_text; }
	else { $blurb = "No blurbs for this movie"; }
	$blurb =~ s/Comments//;
	$blurb =~ s/Full Review//;


	return $score, $blurb;
}

1;
