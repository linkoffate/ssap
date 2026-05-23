PREFIX ?= $(HOME)/.local
BINARY = ssap

.PHONY: build install uninstall clean

build:
	swift build -c release

install: build
	@mkdir -p $(PREFIX)/bin
	@cp .build/release/$(BINARY) $(PREFIX)/bin/$(BINARY)
	@echo "Installed $(BINARY) to $(PREFIX)/bin/$(BINARY)"
	@echo "Run 'ssap install' to set up the daemon and screenshot location."

uninstall:
	@$(PREFIX)/bin/$(BINARY) uninstall 2>/dev/null || true
	@rm -f $(PREFIX)/bin/$(BINARY)
	@echo "Removed $(BINARY) from $(PREFIX)/bin"

clean:
	swift package clean
	rm -rf .build
