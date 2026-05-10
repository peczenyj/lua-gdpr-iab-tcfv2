# Makefile for lua-gdpr-iab-tcfv2

LUA_VERSION ?= 5.4
LUA          = lua$(LUA_VERSION)
LUAROCKS     = luarocks
LUACHECK     = luacheck
STYLUA       = stylua
BUSTED       = busted
LUACOV       = luacov
GIT_CLIFF    = git-cliff

SRC_DIR      = src
TEST_DIR     = test
DIST_NAME    = lua-gdpr-iab-tcfv2
VERSION      = 0.1.0

# Local dependencies path
ROCKS_PATH   = ./.rocks
ROCKS_LUA    = $(ROCKS_PATH)/share/lua/$(LUA_VERSION)/?.lua
ROCKS_BIN    = $(ROCKS_PATH)/bin

# Environment setup for local dependencies
ENV_SETUP    = export LUA_PATH="$(ROCKS_LUA);./src/?.lua;./?.lua;;" && \
               export PATH="$(ROCKS_BIN):$$PATH"

.PHONY: all test lint format coverage changelog dist install clean setup

all: test

setup:
	@echo "Installing development dependencies..."
	$(LUAROCKS) install --only-deps --tree $(ROCKS_PATH) *.rockspec
	@echo "Dependencies installed in $(ROCKS_PATH)/"
	@echo "The Makefile will now automatically use them for 'make test', 'make lint', etc."

test:
	@$(ENV_SETUP) && $(BUSTED) $(TEST_DIR)

lint:
	@$(ENV_SETUP) && $(LUACHECK) $(SRC_DIR) $(TEST_DIR)

format:
	@$(ENV_SETUP) && $(STYLUA) $(SRC_DIR) $(TEST_DIR)

coverage:
	@$(ENV_SETUP) && $(BUSTED) --coverage $(TEST_DIR)
	@$(ENV_SETUP) && $(LUACOV)
	@echo "Coverage report generated in luacov.report.out"

changelog:
	$(GIT_CLIFF) -o CHANGELOG.md

dist:
	@mkdir -p $(DIST_NAME)-$(VERSION)
	@cp -r src LICENSE README.md CHANGELOG.md $(DIST_NAME)-$(VERSION)/
	@tar -czf $(DIST_NAME)-$(VERSION).tar.gz $(DIST_NAME)-$(VERSION)
	@rm -rf $(DIST_NAME)-$(VERSION)
	@echo "Created $(DIST_NAME)-$(VERSION).tar.gz"

install:
	@echo "Installing to standard Lua path..."
	@mkdir -p /usr/local/share/lua/$(LUA_VERSION)/gdpr/iab/tcfv2
	@cp src/*.lua /usr/local/share/lua/$(LUA_VERSION)/gdpr/iab/tcfv2/
	@echo "Done."

clean:
	rm -rf *.tar.gz luacov.*.out luacov.report.out $(ROCKS_PATH)
