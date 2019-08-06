#!/usr/bin/perl
use strict;
use sort 'stable'; # Needed for funny sort later

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

# Translate the strings of column widths in TeX to instruction type codes that look
# like the ones in the manual. Needs further translation based on checking for funct7
# FENCE is a funny variant of "I" with further packing in the immediate
# SYSTEM is formally I-type but all fields are constant except the immediate, which the manual describes as a "funct12".
my %signatureIs = ("811" => "UJ", "61111" => "I", "421111" => "RSB", "2311111" => "FENCE");
sub hashWith { map { $_ => 1 } @_ }
my %hasFunct3 = hashWith(qw(R I S B FENCE));
my %hasFunct7 = hashWith(qw(R));
my %hasFunct12 = hashWith(qw(SYSTEM));
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

# Build @seenOpcodes/%dataOpcodes
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
				my $dataOpcode = {instr => $row{instr}}; # Description of this instruction
				push(@$dataOpcodeArray, $dataOpcode);

				my $signatureCode = $row{signature}; # Signature code
				my $signature = $signatureIs{$signatureCode}; # Signature letter
				my $roughSignature = $signature; # Delete this line
				if (!$signature) { die "For $row{instr} unrecognized signature code $signatureCode" }
				elsif ($opcode eq "SYSTEM") { # SYSTEM is formatted like an I
					$signature = "SYSTEM";
				} elsif ($signature eq "UJ") {
					$signature = leftTagFilter($signature, $lastcol, [qw[U J]])
						or die "For $row{instr} unrecognized immediate code $$lastcol[0]";
				} elsif ($signature eq "RSB") {
					$signature = leftTagFilter($signature, $lastcol, [qw[S B]]);
					if (!$signature) {
						if (isBinary($signature)) { $signature = "R" }
						else { die "For $row{instr} unrecognized immediate code $$lastcol[0]" }
					}
				}

				if ($hasFunct3{$signature}) {
					$$dataOpcode{hasFunct3} = 1;
					$$dataOpcode{FUNCT3} |= (binary($$lastcol[-3]));
				}
				if ($hasFunct7{$signature}) {
					$$dataOpcode{hasFunct7} = 1;
					$$dataOpcode{FUNCT7} |= (binary($$lastcol[0])); # Assume all funct7s also have funct3
				}
				if ($hasFunct12{$signature}) {
					$$dataOpcode{hasFunct12} = 1;
					$$dataOpcode{FUNCT12} |= (binary($$lastcol[0])); # Assume no funct12s have another funct
				}
				if ($$lastcol[1] eq "shamt") {
					$$dataOpcode{shamt} = 1;
				}

				$$dataOpcode{instr} = $row{instr};
				$$dataOpcode{signature} = $signature;

				#print "// $row{instr}: $opcode (";
				#print join(", ", @$lastcol);
				#print(") signature: $signature [$roughSignature] funct " . sprintf("0x%02x",$$dataOpcode{funct}) . " shamt:$$dataOpcode{shamt}\n");
			}
			resetRow();
		} elsif (s/.*?\\multicolumn\{([^\}]*)\}//) { # Looking for \multicolumn{a}{b}{c}{d}, want first and last {} group.
			$row{signature} .= $1; # Use the first {} to build the "signature" (see below)
			my $last = "";
			while (s/^\s*{([^\}]*)\}//) { $last = $1; } # Append the final {} to the $lastcol array
			my $lastcol = $row{lastcol};
			push(@$lastcol, $last);
			if (/\s*\&\s*(\S+)/) { $row{instr} = $1; } # The space after the & is always empty but the last line puts the instruction name there
		}
	} else { # Search for start of table
		$intable = /RV32I Base Instruction Set/;
		resetRow() if ($intable);
	}
}

# sort same funct3 values together within each opcode
for my $key (@seenOpcodes) {
	my $arr = $dataOpcodes{$key};
	@$arr = sort { $$a{hasFunct3} ? $$a{FUNCT3} <=> $$b{FUNCT3} : 0 } @$arr;
}

my $name = "empty";
my $o = ""; # Build this string
sub o { # Append a line to the output string with the given indentation
	my ($i, $v) = @_;
	if ($v) { $o .= ("    "x$i) . $v . "\n"; }
	else { $o .= "\n"; }
}
sub closeSwitch { # The end of every switch() statement is the same
	my ($i, $alreadyBlanked) = @_;
	o() unless ($alreadyBlanked); # Caller may suppress blank line
	o($i+1, "default: {");
	o($i+2, "// TODO REGISTER ERROR");
	o($i+1, "} break;");
	o($i,   "}");
}
sub closeSwitch7 { # The end of the switch() for FUNCT7 is shaped a litle funny
	my ($i) = @_;
	closeSwitch($i+1, 1);
	o($i,"} break;");
}

my $anyOpcodes;
o(0, "void $name(uint32_t instr) {");
o(1, "switch(VREAD(instr, OPCODE)) {"); # A tree of nested switches: First on opcode, then funct3/funct12, then funct7.
for my $opcode (@seenOpcodes) {
	if ($anyOpcodes) { o(); } else { $anyOpcodes = 1; }
	o(2, "case $opcode: {");
	my $instrs = $dataOpcodes{$opcode};
	
	@$instrs > 0 or die "How did you get here??";
	my $firstInstr = $$instrs[0];
	my $topFunct; # Does this instruction use funct3/funct12? If so which one?
	my $lastTopFunct; # If funct3/funct12 is used, what was its last value?
	if ($$firstInstr{hasFunct3}) { $topFunct = "FUNCT3" }
	elsif ($$firstInstr{hasFunct12}) { $topFunct = "FUNCT12" }

	my $i = 3;

	if ($topFunct) {
		o($i, "switch (VREAD(instr, $topFunct)) {");
		$i++;
	}

	for my $instr (@$instrs) { # For each of this opcode's instructions:
		o() if $instr != $firstInstr;
		if ($topFunct) { # Handle funct3/funct12
			my $functValue = $$instr{$topFunct};
			# The funct3/funct12 will be different for each instruction UNLESS funct7 is in use.
			if ($lastTopFunct ne $functValue) { # If the funct3/funct12 changed
				if ($i > 4) { # Close off any funct7 switch we were building
					closeSwitch7(4);
					o();
					$i = 4;
				}
				o($i, sprintf("case 0x%02x: {", $functValue)); # New funct3 case
				$i++;
				if ($$instr{hasFunct7}) {
					o($i, "switch (VREAD(instr, FUNCT7)) {"); # Open new funct7 switch
					$i++;
				}
				$lastTopFunct = $functValue;
			}
			if ($$instr{hasFunct7}) {
				o($i, sprintf("case 0x%02x: {", $$instr{FUNCT7})); # New funct7 case
				$i++;
			}
		}

		# CODE HERE
		o($i, "// $$instr{instr}");

		o(--$i, "} break;") if ($topFunct); # Could be closing a funct3, funct7 or funct12
	}

	if ($i > 4) { # The loop ended but we were still building a funct7. Close it off
		o();
		closeSwitch7(4);
	}

	if ($topFunct) { # Close off a funct3/funct12 switch
		closeSwitch(3);
	}

	o(2, "} break;");
}
closeSwitch(1); # Close opcode switch
o(0, "}");

print("$o\n");

print("////// End main.c //////\n\n");
