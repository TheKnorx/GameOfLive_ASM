#all: main.asm io_handler.asm memory_handler.asm field_handler.asm
#	../compile_wlib_gcc.sh $^

# Makefile created by ChatGPT - it seems to work but dont bet your life on it!
# Makefile for building the whole project and creating the executable ./main
# uses nasm for compiling and gcc (ld) for linking

# Makefile — NASM + GCC build (single-file replacement for compile_wlib_gcc.sh)

SHELL := bash
.ONESHELL:
.SHELLFLAGS := -euo pipefail -c

# ---- toolchain ----
NASM ?= nasm
CC   ?= gcc

NASMFLAGS ?= -f elf64 -g -F dwarf
LDFLAGS   ?= -no-pie

# ---- project ----
TARGET := main

# List your asm sources explicitly (keeps ordering stable & obvious)
SRCS := main.asm io_handler.asm memory_handler.asm field_handler.asm DEBUG_helper.asm core.lib.asm

BUILD_DIR := build
OBJS := $(patsubst %.asm,$(BUILD_DIR)/%.o,$(SRCS))

.PHONY: all clean sanitize_files
all: $(TARGET)

# Ensure build dir exists
$(BUILD_DIR):
	@mkdir -p "$(BUILD_DIR)"

# Compile rule (prints header, indents assembler output)
$(BUILD_DIR)/%.o: %.asm | $(BUILD_DIR)
	@printf '\n== Compiling: %s ==\n' "$$(realpath "$<")"
	@$(NASM) $(NASMFLAGS) "$<" -o "$@" 2>&1 | sed 's/^/  /'
	@printf '  -> %s\n' "$@"

# Link rule (prints header, indents linker output)
$(TARGET): $(OBJS)
	@printf '\n== Linking -> %s/%s ==\n' "$$(pwd)" "$(TARGET)"
	@$(CC) $(LDFLAGS) $(OBJS) -o "$(TARGET)" 2>&1 | sed 's/^/  /'
	@printf '\nBuild successful: %s/%s\n' "$$(pwd)" "$(TARGET)"

test: test.asm core.lib.asm core.lib.inc
	nasm -f elf64 -g test.asm -o test.o
	#nasm -f elf64 -g core.lib.asm -o core.lib.o
	# ld -o test test.o core.lib.o
	# ld -o test test.o
	gcc -no-pie test.o -o test
	rm -f test.o core.lib.o

clean-test:
	rm -f test test.o core.lib.o

clean:
	@printf 'Cleaning up ... removing build directory, target, and gol_* files ...\n'
	@rm -rf "$(BUILD_DIR)" "$(TARGET)" gol_*

# Sanitize all files - replace all tabs with spaces to have a nice and clean layout
sanitize_files:
	@set -e; \
	for f in *.asm; do \
		expand -t 4 "$$f" > "$$f.tmp"; \
		mv "$$f.tmp" "$$f"; \
	done

# Build animation using the generated gol_*.pbm pictures
animation:
	@printf 'Creating gol.gif from gol_* animation-images ...'
	@magick $$(ls -v gol_*.pbm) -filter point -resize 300% -delay 20 gol.gif
	@printf ' done\n'
	@printf 'Removing all animation images ...'
	@rm -f gol_*
	@printf ' done\n'