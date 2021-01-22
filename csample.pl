#!/usr/bin/perl

# This script creates various types of samples from concordances created with the Open
# Corpus Workbench. It has options for including or excluding the standard  CWB header 
# (and will insert information about sample size and sample method into the header
# but most methods can be used with any text file. If you use it with files other than 
# those containing a CWB concordance, note that you should not use the option
# --header, as this will treat all lines beginning with a hashtag as belonging to a.
# header.
#
# Usage:
#
# csample.pl --method […] --basis […] --offset […] --header --format […]
# csample.pl -m […] -b […] -o […] -h -f […]
#
# Overview of the options:
#
# --method/-m    specifies which method to use:
#                'sp' (or 'systematicproportion') provides n-th line selection with 
#                     the size of the sample is determined by the value of n
#                     provided by the --basis flag (with a default value of 2); 
#                     this is the default method
#                'sf' (or 'systematicfixed' provides n-th line selection with the 
#                     value of n calculated based on the desired size of the sample
#                     provided by the --basis flag (with a default of 50);
#                     note that this method is only available if the concordance
#                     has a standard CWB header
#                     see: https://en.wikipedia.org/wiki/Systematic_sampling
#                'rp' (or 'randomproportion') provides random sampling, where a
#                     each line is randomly included or excluded based on the
#                     probability provided by the --basis flag (with a default of
#                     0.5); (the size of the sample will approximate a percentage of the 
#                     sample corresponding to this probability)
#                'rf' (or 'randomfixed') provides a random sample of the
#                     size provided by the --basis flag (with a default of 50);
#                     see https://stackoverflow.com/a/856559
#
# --basis/-b    (must be an integer), determines the sample size as described above
#
# --offset/-o    (must be an integer), this is only available for the method 'sp', where
#                it can be used to specify which line should be the first line to be 
#                included in the sample (with a default value of 0)
#
# --header/-h    specifies whether the CWB header should be included; if included, this
#                header will be modified to include information about the sample size
#                and method
#
# --format/-f    this specifies the output format: 'txt' produces a simple text file 
#                matching the input (this is the default); csv transforms it into a csv
#                file (like tidycwb.pl), provided the match is enclosed in <angled
#                brackets> (which is the CWB default)
#
# (c) 2021 Anatol Stefanowitsch, GNU General Public License 3.0.

# The script can be used with strict and warnings
# use diagnostics;
# use strict;
# use warnings;
# use 5.010;

use Getopt::Long qw(GetOptions);

Getopt::Long::Configure qw(gnu_getopt);

# Declare all global variables, hashes and arrays

my $method = "sp";
my $basis = 0;
my $head = 0;
my $format = "txt";
my $offset = 0;
my %result;
my @header;
my @sample;
my $comment;

# read the flags (if present)

GetOptions('method|m=s' => \$method, 'basis|b=f' => \$basis, 'header|h' => \$head, 'format|f=s' => \$format, 'offset|o=i' => \$offset);

# set default values for the selected method in case the corresponding flags were not
# used, pass the values to the the subroutine for that method and run the subroutine

if ($method =~ m/s(ystematic)?p(roportion)?/) {

		if ($basis == 0){

			$basis = 2;

		}elsif ($basis < 1) {
		
			$basis = 2;
			
			$comment = "# The specified n for nth-case selection was less than one. Switched to a \n# default of n = 2.\n";
		
		}elsif ($basis == 1) {

			$comment = "# The specified n for nth-case selection was 1. The sample is identical \n# to the original concordance.\n";
		
		}
		
		if ($offset == 0) {
		
			$offset = $basis;
		
		}

		%result = &sysprop(BASIS => $basis, OFFSET => $offset);
		
	}elsif ($method =~ m/s(ystematic)?f(ixed)?/) {

		if ($basis == 0){

			$basis = 50;

		}

		%result = &sysfixed(BASIS => $basis);

	}elsif ($method =~ m/r(andom)?p(roportion)?/) {

		if ($basis == 0){

			$basis = 0.5;
			
		}elsif ($basis >= 1) {
			
			$basis = $basis/100;

			$comment = "# The specified probability was equal to or greater than one and was \n# interpreted as a percentage (p = ".$basis.").\n";
			
			}

		%result = &randprop(BASIS => $basis);
	
	}elsif ($method =~ m/r(andom)?f(ixed)?/) {
	
		if ($basis == 0){

			$basis = 50;
			
		}elsif ($basis < 1) {
		
			$basis = 50;

			$comment = "# The specified sample size was less than one. Switched to a default \n# sample size of 50 lines.\n";
		
		}

		%result = &randfixed(BASIS => $basis);
	
	}else{
	
		if ($basis == 0){

			$basis = 2;

		}elsif ($basis < 1) {
		
			$basis = $basis * 100;
		
		}
		
		if ($offset == 0) {
		
			$offset = $basis;
		
		}
		
		$comment = $comment."# An unknown sampling method was selected. Switched to systematic \n# sampling on an n-th case basis with n=".$basis.".\n";

		%result = &sysprop(BASIS => $basis, OFFSET => $offset);
	
	}

# if the --header option was chosen, print the header, modifying the line with
# size information to include the sample size and the percentage of the total
# represented by the sample and adding a line with the sampling method used (this
# information is provided in a hash returned by the subroutine)

if ($head == 1) {

	@header = @{$result{"HEADER"}};

	my ($index) = grep { $header[$_] =~ m/Size/} 0 .. $#header;

	$header[$index] = "# Size:    ".$result{"SIZE"}." of ".$result{"COUNT"}." hits (".$result{"PERCENT"}." percent)\n# Method:  ".$result{"METHOD"}."\n";

	foreach (@header) {

		print $_;

	}

}

# if the comment variable has content, print the comments

if ($comment ne "") {

	if ($head == 0){
	
		print "#---------------------------------------------------------------------------\n";	
	
	}
	print "# Warnings:\n".$comment."#---------------------------------------------------------------------------\n";

}

# get the sample array from the hash holding the variables returned by the method

@sample = @{ $result{"SAMPLE"} };

# if the flag --method was used with the argument csv, convert the contents of the
# array to csv format

if ($format =~ m/csv/) {

	foreach (@sample) {

		s/\"/''/g;
		s/^ *(\d+):\s+/$1\"\,\"/;
		s/ <(\S+[^<>]+)> /\"\,\"$1\"\,\"/;
		s/<(\S+) (\S+)>:?\s*/$2\"\,\"/g;
		s/^(.*)$/\"$1\"/;
										
	}

}

# print the sample array

foreach (@sample) {

	print $_;

}


# here are the subroutines for the sampling methods

# sysprop draws a systematic sample on an n-th case basis

sub sysprop {

# declare local variables

	my @header;
	my @sample;
	my %result;
	my $count;
	my $size;
	my $line;

# get the arguments BASIS and OFFSET passed from the main routine

	my %args = (
		@_,
	);

# initialize the value of $line so that it will start selecting lines when the value
# specified by OFFSET is reached (if OFFSET is empty, it will start selecting immediately)

	$line = $args{"BASIS"} - abs($args{"OFFSET"} - 1);

	while (<>) {
	
# store the header in an array, in case it is needed for the output

		if ($_ =~ m/^#/) {

			push (@header, $_);

		}else{

# go through the concordance, adding every nth line to the sample
	
			$count++;

			if($line == $args{"BASIS"}) {

					$line = 0;

					$size++;
				
					push (@sample, $_);
		
			}

			$line++;

		}

	}

# put the results and all relevant information into a hash an return it to main

	%result = (
		METHOD => "Systematic (n = ".$args{BASIS}.")",
		HEADER => \@header,
		SAMPLE => \@sample,
		SIZE => $size,
		COUNT => $count,
		PERCENT => int((($size/$count) * 100)+0.5),
		);

	return %result;

} # end sysprop

# sysfixed draws a sample of a fixed size on an n-th line basis; this method works only if the concordance has a standard CWB header, as it needs to know the size of the concordance to calculate n

sub sysfixed {

# declare local variables

	my @header;
	my @sample;
	my %result;
	my $count;
	my $size;
	my $line = 1;
	my $n;
	my $N;
	my $k;

# get the argument BASIS passed from the main routine

	my %args = (
		@_,
	);

# store the header in an array in case it is needed later

	while (<>) {
	
# get the size of the concordance from the header

		if ($_ =~ m/^# Size: *(\d+) .*/) {

			$N = $1;

# calculate n for the nth-case selection, determine choose a random line smaller than 
# n as the first line to be included in the sample
			
			$n = $N/$args{"BASIS"};

			$line = rand($n);

# add the header line with the size information to the header array

			push (@header, $_);

		}elsif ($_ =~ m/^#/) {

			push (@header, $_);

# go through the concordance and select every nth line (note that n may not be
# an integer, so the procedure in the Wikipedia link above is followed to make
# sure the sample has exactly the right size)
		
		}else{
	
			$count++;

			if($count == int($line + 1)) {

				$size++;

				$line = $line + $n;
	
				push (@sample, $_);
		
			}

		}

	}

# pass the results back to main

	%result = (
		METHOD => "Systematic (Fixed)",
		HEADER => \@header,
		SAMPLE => \@sample,
		SIZE => $size,
		COUNT => $count,
		PERCENT => int((($size/$count) * 100)+0.5),
		);

	return %result;

} # end sysfixed

# randprop selects lines based on a probability provided

sub randprop {

# declare local variables

	my @header;
	my @sample;
	my %result;

	my $rnd;
	my $size;
	my $count;

# get the BASIS argument passed from the main routine

	my %args = (
		@_,
	);

	while (<>) {

# store the header in an array in case it is needed later

		if ($_ =~ m/^#/) {
	
			push (@header, $_);
		
		}else{

			$count++;

# create a random number between 0 and 1, if the provided p is less than or equal to
# that number, include it in the sample

			$rnd = rand(1);

			if ($rnd <= $args{"BASIS"}) {

				$size++;
	
				push (@sample, $_);

			}

		}

	}

# sort the sample

	@sample = sort(@sample);

# return the results to the main routine

	%result = (
		METHOD => "Random (p = ".$args{BASIS}.")",
		HEADER => \@header,
		SAMPLE => \@sample,
		COUNT => $count,
		SIZE => $size,
		PERCENT => int((($size/$count) * 100)+0.5),
	);

	return %result;

} # end randprop

# randfixed selects a random sample of n lines

sub randfixed {

# declare local variables

	my @header;
	my @sample;
	my %result;

	my $rnd;
	my $count = 0;

# get the BASIS argument passed by the main routine

	my %args = (
		@_,
	);
	
# store the header in an array in case it is needed later

	while (<>) {

		if ($_ =~ m/^#/) {
		
			push (@header, $_);
		
		}else{

			$count++;

# initialize the sample by selecting the first n lines (this makes sure we have 
# at least that number)

			if ($count <= $args{"BASIS"}) {

				push (@sample, $_);
	
			}else{

# for each successive line, decide randomly whether to include it, with decreasing 
# probability; if selected, randomly replace one of the lines in the sample array
	
				$rnd = rand(1);
		
				if ($rnd <= $args{"BASIS"}/$count) {
		
					$sample[rand(@sample)] = $_;
		
				}
		
			}

		}

	} 

# sort the sample

	@sample = sort(@sample);

# return the results to the main routine

	%result = (
		METHOD => "Random (Fixed Size)",
		HEADER => \@header,
		SAMPLE => \@sample,
		COUNT => $count,
		SIZE => $args{"BASIS"},
		PERCENT => int((($args{"BASIS"}/$count) * 100) + 0.5),
	);

	return %result;
	
}# sub randabs
