#!/usr/bin/perl

use ExtUtils::MakeMaker;

WriteMakefile(FIRST_MAKEFILE => 'Makefile.perl',
	      PMLIBDIRS => ['Debbugs'],
	      NAME => 'Debbugs',
	      VERSION => '2.4.2',
	     );
