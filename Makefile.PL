use ExtUtils::MakeMaker;
WriteMakefile(
	NAME				=> "Device::ScanShare",
	VERSION_FROM	=> 'lib/Device/ScanShare.pm',
	PREREQ_PM 		=> {
		'File::Slurp'	=> '0',
		'Smart::Comments' => 0,
		'File::Path'	=> '0',
		'YAML' => '0',
		'Getopt::Std' => '0',
		Carp => 0,
	},
	EXE_FILES		=> ['bin/scanshare'],
);
