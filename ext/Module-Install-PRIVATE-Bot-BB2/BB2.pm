package Module::Install::PRIVATE::Bot::BB2;
use strict;
use base 'Module::Install::Base';
use FindBin qw($Bin);
use File::Spec ();
use File::Copy::Recursive qw(rcopy);

our $VERSION = '0.02';

sub to_bb2_in_blib
{
    my ($self, $from, $to) = @_;

    printf "*** %s\n", __PACKAGE__;

    # Go to the dir Makefile.PL is in
    chdir $Bin;

    my @path = split '-', $self->name;
    # Copy F<plugins> to F<blib/lib/Bot/BB2/plugins>

    my $blibdir = File::Spec->catdir(qw(blib lib) => @path => $to);
    rcopy($from => $blibdir);

    printf "*** %s finished\n", __PACKAGE__;

    undef;
}

1;

__END__

=head1 NAME

Module::Install::PRIVATE::Bot::BB2 - C<M::I> utility routines for L<Bot::BB2>

=head1 METHODS

=head2 to_bb2_in_blib

Copies the contents of a specified directory to a given directory
under F<Bot/BB2> in F<blib/>. The latter will exist in the perl module
directory once installed.

example:

    # copy plugins/* to blib/lib/BB2/Bot/Plugins/
    to_bb2_in_blib plugins => Plugin;

=head1 AUTHOR

E<AElig>var ArnfjE<ouml>rE<eth> Bjarmason <avar@cpan.org>

=cut
