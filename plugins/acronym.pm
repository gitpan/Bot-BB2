use WWW::Mechanize;
use HTML::Entities;

{
	code => sub {
		my ($self, $said, $acronym) = @_;
		
		my $mech = WWW::Mechanize->new;
		
		$mech->get("http://www.acronymfinder.com");
		$mech->agent_alias('Windows IE 6');
		
		my $result = $mech->submit_form(
			form_name => 'findform',
			fields    => {
				Acronym => $acronym
			},
		);
		
		my $final = $result->content;
		
		my @output;
		
		while ($final =~ m{
				<td (?: \s+ (?: width | valign | bgcolor) = " [^"]+ ")+> ([^<]+) \s* </td>\s*
				<td (?: \s+ (?: width | valign | bgcolor) = " [^"]+ ")+> ([^<]+) \s* </td>
			}gxms
		) {
			my $expansion = decode_entities($2);
			$expansion =~ s{(?: \A \s+ ) | (?: \s+ \z )}{}gxms;
			push @output, $expansion;
		}
		
		print((join ', ', @output) . '.');
	}
}