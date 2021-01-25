#include "riscv.h"
#include <stdio.h>
#include <vector>
#include <string>

using namespace std;

int main(int argc, char **argv) {
	bool printHelp = false;
	bool printArgFail = false;
	bool extArg = false;
	vector<string> args;

	for(int c = 1; c < argc; c++) {
		string arg = argv[c];
		bool fileArg = false;

		if (extArg) {
			fileArg = true;
		} else if (arg == "--help") {
			printHelp = true;
		} else if (arg == "--") {
			extArg = true;
		} else if (arg[0] == '-') {
			printf("Error: Unrecognized argument: %s\n\n", argv[c]);
			printArgFail = true;
		} else {
			fileArg = true;
		}

		if (fileArg) {
			args.push_back(arg);
		}
	}

	int inSize;
	FILE *f = NULL;

	if (args.size() == 0) {
		printf("Error: No input file\n\n");
		printArgFail = true;
	} else {
		const string &infile = args[0];

		f = fopen(infile.c_str(), "r");
		if (!f) {
			printf("Error: Could not open input file: %s\n\n", infile.c_str());
			printArgFail = true;
		} else {
			fseek(f, 0L, SEEK_END);
			inSize = ftell(f);
			fseek(f, 0L, SEEK_SET);
		}
	}

	if (printHelp || printArgFail) {
		printf("Usage: %s <filename>", argv[0]);
		return printArgFail;
	}

	vector<uint32_t> binary;
	int items = inSize/sizeof(uint32_t);
	binary.resize(items);
	fread(&binary[0], items, sizeof(uint32_t), f); // FIXME: Assumes little endian host arch

	Emulator emu(1024);
	for(int c = 0; c < items; c++) {
		emu.run(binary[c]);
	}

	return 0;
}