#!/usr/bin/perl

use strict;
use warnings;
use FindBin;
BEGIN { %make:: or do { require "$FindBin::Bin/tool/make.pm"; make->import(':all') } }
use autodie qw(:all);

my $here;

workflow {

    sub doths { "$_[0]/$_[0].hs" }
    sub dotnes { "$_[0]/$_[0].nes" }
    sub dotexe { "$_[0]/$_[0].exe" }

    sub module {
        my ($name) = @_;
        rule dotexe($name), doths($name), sub {
            system 'ghc', '-ilib', '-fno-warn-deprecated-flags', doths($name), '-o', dotexe($name);
        };
        rule dotnes($name), dotexe($name), sub {
            system(dotexe($name) . ' > ' . dotnes($name));
        };
    }

    subdep 'lib/ASM.hs', 'lib/Assembly.hs';
    subdep 'lib/ASM6502.hs', 'lib/ASM.hs';
    subdep 'lib/NES.hs', 'lib/ASM6502.hs';
    subdep 'lib/NES/ASoundEngine.hs', 'lib/NES.hs';
    subdep doths('soundtest'), 'lib/NES/ASoundEngine.hs';
    subdep doths('controllertest'), 'lib/NES.hs';
    module 'soundtest';
    module 'controllertest';

    phony 'build', [dotnes('soundtest'), dotnes('controllertest')], sub { };

    phony 'clean', [], sub {
        unlink glob '*/*.nes */*.exe */*.hi */*.o */*/*.hi */*/*.o';
    };

    defaults 'build';

}


