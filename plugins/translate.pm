use WWW::Babelfish;

{
    code => sub {
        splice @_, 0, 2;
        my ($from, $to) = splice @_, 0, 2;
        my $text = join ' ', @_;
        
        my $babelfish = WWW::Babelfish->new(service => 'Google');
        if (my $result = $babelfish->translate(source => ucfirst $from, destination => ucfirst $to, text => $text)) {
            print "$result\n";
        } else {
            print "Error in translation: " . $babelfish->error . "\n";
        }
    }
}
