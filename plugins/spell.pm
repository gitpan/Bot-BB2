use Text::Aspell;

{
    code => sub {
        my $word = $_[2];
        my $speller = Text::Aspell->new;
        
        if ($speller->check($word)) {
            print "$word seems to be the correct spelling.";
        } else {
            print "$word doesn't seem to be in the dictionary, perhaps you meant one of these: " . join ', ', $speller->suggest($word);
        }
    }
}