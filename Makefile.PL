use ExtUtils::MakeMaker;
WriteMakefile(
	      NAME	=> 'PythonTech::CGI',
	      VERSION => '1.1',
	      ABSTRACT => 'CGI extension',
	      AUTHOR => 'Colin Hogben <perl@pythontech.co.uk>',
	      PREREQ_PM => {
		Test::More => 0.32,
	      },
	      );
