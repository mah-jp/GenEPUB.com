#!/usr/bin/perl

use lib './extlib/lib/perl5';
use strict;
use warnings;
use GenEPUB;

my $dir = substr($ENV{'SCRIPT_FILENAME'}, 0, rindex($ENV{'SCRIPT_FILENAME'}, '/')) . '/';
my $app = GenEPUB->new(
		PARAMS => {
			config_file => $dir . '../private/genepub.ini',
			template_dir => $dir . './template',
			amazon_dir => $dir . '../private/amazon',
			epub_dir => $dir . '../private/epub',
		}
	);
$app->run();
