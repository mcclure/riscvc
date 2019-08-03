#!/usr/bin/perl
use strict;

# Argument is path to opcode-map.tex from https://github.com/riscv/riscv-isa-manual
my ($path) = @ARGV;
$path or die "Please give path to opcode-map.tex";
open(FH, $path) or die "Couldn't open $path";

my $tabley;
for(<FH>) {
	my @line = split(" & "); # This file seems to use this as a delimiter

	# Table has: 2 top rows label, 1 label column left and right, content is 7x4
	if (@line >= 9) {
		if ($tabley >= 2) {
			for my $tablex (1..7) {
				my $opcode = $line[$tablex];
				$opcode =~ s/^\s*(\S*)\s*$/$1/s;
				next if ($opcode =~ /\{/); # Ignore anything italicised for now
				$opcode =~ s/-/_/g;
				$opcode .= " "x(9-length($opcode)); # Pad to 9 chars

				my $value = 0b11; # Standard instruction set
				$value |= ( ($tablex - 1) << 2 ); # "inst[4:2]"
				$value |= ( ($tabley - 2) << 5 ); # "inst[6:5]"
				$value = sprintf("  0x%02x     // %d", $value, $value);

				print("#define $opcode $value\n")
			}
		}
		$tabley++;
	}
}
