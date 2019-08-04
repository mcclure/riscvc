#!/usr/bin/perl
use strict;

# Argument is path to opcode-map.tex from https://github.com/riscv/riscv-isa-manual
my ($path) = @ARGV;
$path or die "Please give path to opcode-map.tex and instr-table.tex";

my $tp;
$tp = "$path/opcode-map.tex"; open(FH, $tp) or die "Couldn't open $tp";

print("////// Paste into riscv.h //////\n\n");

my %opcodes = ();

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
				my $opcodepad = " "x(9-length($opcode)); # Pad to 9 chars

				my $value = 0b11; # Standard instruction set
				$value |= ( ($tablex - 1) << 2 ); # "inst[4:2]"
				$value |= ( ($tabley - 2) << 5 ); # "inst[6:5]"
				my $valuestr = sprintf("  0x%02x     // %d", $value, $value);

				print("#define $opcode$opcodepad $valuestr\n");
				$opcodes{$value} = $opcode;
			}
		}
		$tabley++;
	}
}

close(FH);

print("\n////// End riscv.h //////\n\n");

$tp = "$path/instr-table.tex"; open(FH, $tp) or die "Couldn't open $tp";

print("////// Paste into main.c //////\n\n");

# R-type: 421111 (funct7, rs2, rs1, funct3, rd, opcode)
# I-type: 61111 (imm[11:0], rs1, funct3, rd, opcode)
# S-type: 421111 (imm[11:5], rs2, rs1, funct3, imm[4:0], opcode)
# B-type: 421111 (imm[12$\vert$10:5], rs2, rs1, funct3, imm[4:1$\vert$11], opcode)
# U-type: 811 (imm[31:12], rd, opcode)
# J-type: 811 (imm[20$\vert$10:1$\vert$11$\vert$19:12], rd, opcode)

my $intable;  # As we scan the file: Are we looking at the RV32I table?
my %row = (); # Data for this row of the table (the gap between a lone & and a \cline)
sub resetRow { %row = ("lastcol" => [], "signature" => ""); }

my @seenOpcodes = (); # Order in which opcodes were first seen in the table
my %dataOpcodes = (); # Arrays of instruction data sorted by opcode
my %kindOpcode = ();  # What instruction decode does each opcode use?

# Translate the strings of column widths in TeX to instruction type codes that look
# like the ones in the manual. Needs further translation based on checking for funct7
# FENCE is a funny variant of "I" with further packing in the immediate
my %signatureIs = ("811" => "UJ", "61111" => "I", "421111" => "RSB", "2311111" => "FENCE");
sub hashWith { map { $_ => 1 } @_ }
my $hasFunct3 = hashWith(qw(R I S B FENCE));
my $hasFunct7 = hashWith(qw(R));
my %leftTag = (S => "imm[11:5]", B => 'imm[12$\\vert$10:5]', U => "imm[31:12]", "J" => 'imm[20$\\vert$10:1$\\vert$11$\\vert$19:12]');

sub isBinary { return $_[0] !~ /[^01]/ }
sub binary { return oct("0b".$_[0]) } # Binary string -> number
sub leftTagFilter { # Converts RSB -> R, S or B, UJ -> U or J (returns undef for R)
	my ($signature, $lastcol, $whitelistRef) = @_;
	for my $key (@$whitelistRef) {
		if ($$lastcol[0] eq $leftTag{$key}) {
			return $key;
		}
	}
}

for(<FH>) { # Scan line by line
	if ($intable) { # Between table title and \end
		if (/\\end/) { $intable = 0; next; } # Done with entire table
		elsif (/\\cline/) { # Done with one row
			if ($row{instr}) { # Did you get an instruction name?
				my $lastcol = $row{lastcol}; # Columns in the row [ie the last tex argument of each stanza]
				my $opcode = $opcodes{binary($$lastcol[-1])}; # Opcode name
				my $dataOpcodeArray = $dataOpcodes{$opcode}; # Instructions of this opcode 
				if (!$dataOpcodeArray) { # This is the first instruction of this opcode
					push(@seenOpcodes, $opcode);
					$dataOpcodeArray = [];
					$dataOpcodes{$opcode} = $dataOpcodeArray;
				}
				my $dataOpcode = {}; # Description of this instruction
				push(@$dataOpcodeArray, $dataOpcode);

				my $signatureCode = $row{signature}; # Signature code
				my $signature = $signatureIs{$signatureCode}; # Signature letter
				my $roughSignature = $signature; # Delete this line
				if (!$signature) { die "For $row{instr} unrecognized signature code $signatureCode" }
				elsif ($signature eq "UJ") {
					$signature = leftTagFilter($signature, $lastcol, [qw[U J]])
						or die "For $row{instr} unrecognized immediate code $$lastcol[0]";
				} elsif ($signature eq "RSB") {
					$signature = leftTagFilter($signature, $lastcol, [qw[S B]]);
					if (!$signature) {
						if (isBinary($signature)) { $signature = "R" }
						else { die "For $row{instr} unrecognized immediate code $$lastcol[0]" }
					}
				}

				my $lastcol = $row{lastcol};
				print "// $row{instr}: $opcode (";
				print join(", ", @$lastcol);
				print(") signature: $signature [$roughSignature]\n");
			}
			resetRow();
		} elsif (s/.*?\\multicolumn\{([^\}]*)\}//) { # Looking for \multicolumn{a}{b}{c}{d}, want first and last {} group
			$row{signature} .= $1;
			my $last = "";
			while (s/^\s*{([^\}]*)\}//) { $last = $1; }
			my $lastcol = $row{lastcol};
			push(@$lastcol, $last);
			if (/\s*\&\s*(\S+)/) { $row{instr} = $1; }
		}
	} else { # Search for start of table
		$intable = /RV32I Base Instruction Set/;
		resetRow() if ($intable);
	}
}
