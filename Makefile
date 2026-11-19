NASM ?= nasm
CC ?= gcc
WIN_CC ?= x86_64-w64-mingw32-gcc
CFLAGS ?= -no-pie
WINFLAGS ?= -municode -static

.PHONY: all linux windows installer appimage test gui-test clean
all: linux
linux: dist/helix-linux-x86_64
windows: dist/helix-core.exe dist/helix.exe

# Standalone language engine used internally by the Windows GUI app.
dist/helix-core.exe: src/helix.asm
	mkdir -p dist
	$(NASM) -f win64 $< -o dist/helix-core.obj
	$(WIN_CC) $(WINFLAGS) dist/helix-core.obj -lshell32 -luser32 -lkernel32 -o $@

# Main Helix application: starts its integrated terminal, or opens a .hlx file.
dist/helix.exe: src/helix_terminal.asm
	mkdir -p dist
	$(NASM) -f win64 $< -o dist/helix-ui.obj
	$(WIN_CC) $(WINFLAGS) -mwindows dist/helix-ui.obj -lcomdlg32 -luser32 -lgdi32 -lkernel32 -o $@

dist/helix-linux-x86_64: src/helix.asm
	mkdir -p dist
	$(NASM) -f elf64 $< -o dist/helix-linux-x86_64.o
	$(CC) $(CFLAGS) dist/helix-linux-x86_64.o -o $@

dist/helix-terminal-linux: src/helix_terminal_linux.c
	mkdir -p dist
	$(CC) -std=c11 -O2 -Wall -Wextra -Wpedantic $$(pkg-config --cflags gtk+-3.0) $< -o $@ $$(pkg-config --libs gtk+-3.0)

installer: dist/helix.exe dist/helix-core.exe
	makensis setup.nsi

appimage:
	packaging/build-appimage.sh

test: dist/helix-linux-x86_64
	bash tests/smoke.sh ./dist/helix-linux-x86_64
	bash tests/bridges.sh ./dist/helix-linux-x86_64

gui-test: dist/helix-linux-x86_64 dist/helix-terminal-linux
	HELIX_GUI="$(abspath dist/helix-terminal-linux)" HELIX_CORE="$(abspath dist/helix-linux-x86_64)" bash tests/gui_smoke.sh

clean:
	rm -f dist/helix-linux-x86_64 dist/helix-linux-x86_64.o dist/helix-terminal-linux dist/helix-core.exe dist/helix-core.obj dist/helix.exe dist/helix-ui.obj dist/Helix-Setup-*.exe
