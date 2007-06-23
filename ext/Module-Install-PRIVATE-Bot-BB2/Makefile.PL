use inc::Module::Install;

name 'Module-Install-PRIVATE-Bot-BB2';
author 'Ævar Arnfjörð Bjarmason <avar@f-prot.com>';

abstract_from 'BB2.pm';
version_from  'BB2.pm';
license       'perl';

requires(
    'FindBin' => 0,
    'File::Spec' => 0,
    'File::Copy::Recursive' => 0,
);

# t/
build_requires 'Test::More';

auto_install;

tests 't/*.t';

WriteAll;
