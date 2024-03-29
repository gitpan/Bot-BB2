######################################################################
#
# MakeMaker file for JavaScript::SpiderMonkey
#
# Revision:     $Revision: 1.3 $
# Last Checkin: $Date: 2006/02/28 17:13:08 $
# By:           $Author: thomas_busch $
#
# Authors: Mike Schilli  m@perlmeister.com, 2002-2005
#          Thomas Busch  tbusch@cpan.org, 2006
#
######################################################################

# Get the right lib and include dirs for different platforms

my $JS_LIB_DIR;
my @JS_INCL_DIRS;

my @c_header_files = qw(
  jsapi.h
  jsautocfg.h
);

my @possible_libraries = qw(
  libjs.a
  js32.dll
);

my %possible_install_paths = (
  "../js/src/*"      => "../js/src",
  "/usr/lib"         => "/usr/include",
  "/usr/local/lib"   => "/usr/local/include",
);

foreach my $install_path(keys %possible_install_paths) {
  foreach my $possible_lib(@possible_libraries) {
    foreach my $libfile(glob "$install_path/$possible_lib") {
      next if ! -f $libfile;
      my $include_path = $possible_install_paths{$install_path};
      foreach my $c_header(@c_header_files) {
        if (-f "$include_path/$c_header") {
          my $include_dir = "$include_path/$c_header";
          $include_dir =~ s/$c_header$//;
          push @JS_INCL_DIRS, $include_dir;
        }
        foreach my $headerfile(glob "$include_path/*/$c_header") {
          my $include_dir = $headerfile;
          $include_dir =~ s/$c_header$//;
          push @JS_INCL_DIRS, $include_dir;
        }
      }
      if (scalar(@JS_INCL_DIRS) == scalar(@c_header_files)) {
        $JS_LIB_DIR = $libfile;
        $JS_LIB_DIR =~ s/$possible_lib$//;
        last;
      } else {
        @JS_INCL_DIRS = ();
      }
    }
    last if $JS_LIB_DIR;
  }
  last if $JS_LIB_DIR;
}

if ($JS_INCL_DIRS[0] eq $JS_INCL_DIRS[1]) {
  shift @JS_INCL_DIRS;
}

## If no SpiderMonkey library found report that and exit.
## Otherwise print lib and include paths.

if (!$JS_LIB_DIR) {
    print <<EOT;

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
This module requires the SpiderMonkey C library -- please read the
README file on how to download, compile and link it.
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

EOT
    exit 0;
} else {
  print "JS_LIB_DIR:  $JS_LIB_DIR\n";
  foreach my $include_dir(@JS_INCL_DIRS) {
    print "JS_INCL_DIR: $include_dir\n";
  }
}

## Determine library name and system-related defines

my $JS_LIB_NAME;
my $JS_DEFINE;

if ($^O ne 'MSWin32') {
  $JS_LIB_NAME = 'js';
  $JS_DEFINE  = '-DXP_UNIX';
} else {
  $JS_LIB_NAME = 'js32';
  $JS_DEFINE  = '-DXP_WIN';
};


use ExtUtils::MakeMaker;

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		=> 'JavaScript::SpiderMonkey',
    'VERSION_FROM'	=> 'SpiderMonkey.pm', # finds $VERSION
    'PREREQ_PM'		=> {
        'Log::Log4perl' => 0,
        'Data::Dumper'  => 0,
                           }, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM => 'SpiderMonkey.pm', # retrieve abstract from module
       AUTHOR     => 'Mike Schilli <m@perlmeister.com>') : ()),
    'LIBS'		=> ["-L$JS_LIB_DIR -l$JS_LIB_NAME"], # e.g., '-lm'
    'DEFINE'		=> $JS_DEFINE, # e.g., '-DHAVE_SOMETHING'
	# Insert -I. if you add *.h files later:
    'INC'		=> "-I".join " -I", @JS_INCL_DIRS,
	# Un-comment this if you add C files to link with later:
    # 'OBJECT'		=> '$(O_FILES)', # link all the C files too
);

######################################################################
sub MY::postamble {
######################################################################
    '
README: SpiderMonkey.pm
	pod2text SpiderMonkey.pm >README
    ';
}
