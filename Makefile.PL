#!/usr/bin/perl

use ExtUtils::MakeMaker;

WriteMakefile(FIRST_MAKEFILE => 'Makefile.perl',
	      PMLIBDIRS => ['Debbugs'],
	      EXE_FILES => ['bin/local-debbugs',
			    'bin/add_bug_to_estraier',
			   ],
	      NAME => 'Debbugs',
	      VERSION => '2.4.2',
	     );
