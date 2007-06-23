# for the OEIS plugin to buubot by b_jonas

use warnings;
use strict;
use CGI;
use LWP::Simple;

{
	code => sub {
		my($self, $said, $q) = @_;

		if( $q =~ /^\s*(?:(?:help|wtf|\?)\s*)?$/i )
		{
			print "see http://tinyurl.com/7xmvs and http://tinyurl.com/2blo2w";
			return;
		}
		my $uri = "http://www.research.att.com/~njas/sequences/?q=" . CGI::escape($q) . "&n=1&fmt=3";
		local $_ = get($uri); # change this in the real plugin
		if (/^Results .* of (\d+) results/mi) {
			my $nrfound = $1;
			unless( /^%N (\S+) (.*)/m )
			{
				print "Reply from OEIS in unknown format 2";
				return;
			}
			my($anum, $title) = ($1, $2);
			my $elts_re = /^%V/m ? qr/^%[VWX] \S+ (.*)/m : qr/^%[STU] \S+ (.*)/m;
			my $elts = join ",", /$elts_re/g;
			$elts =~ s/,,+/,/g;
			my $moremsg = 1 == $nrfound ? "" : sprintf " (1/%d)", $nrfound;
			print sprintf "%.10s%s %.256s: %.512s", $anum, $moremsg, $title, $elts;
			return;
		} elsif (/^no matches/mi) {
			print "No matches found";
			return;
		} else {
			print "Reply from OEIS in unknown format";
			return;
		}
	}
}

