#!/usr/bin/perl
use strict;

# Argument is path to instr-table.tex from https://github.com/riscv/riscv-isa-manual
my ($path) = @ARGV;
$path or die "Please give path to instr-table.tex";
open(FH, $path) or die "Couldn't open $path";

my $intable;

my %row

for(<FH>) {
	if ($intable) {
		if (/\/end/) { $intable = 0; next; }
		if (/\/cline/) {
			if ($row{})
		}
	} else {
		$intable = /RV32I Base Instruction Set/;
		%row = ();
	}
}