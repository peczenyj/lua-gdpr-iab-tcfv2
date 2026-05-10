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

# Set LUA_PATH to include src and test directories
LUA_PATH_SET = "./?.lua;./src/?.lua;./test/?.lua;;"

.PHONY: all test lint format coverage changelog dist install clean

all: test

test:
	@export LUA_PATH="$(LUA_PATH_SET)" && $(BUSTED) $(TEST_DIR)

lint:
	$(LUACHECK) $(SRC_DIR) $(TEST_DIR)

format:
	$(STYLUA) $(SRC_DIR) $(TEST_DIR)

coverage:
	@export LUA_PATH="$(LUA_PATH_SET)" && $(BUSTED) --coverage $(TEST_DIR)
	$(LUACOV)
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
	@cp src/gdpr/iab/tcfv2/*.lua /usr/local/share/lua/$(LUA_VERSION)/gdpr/iab/tcfv2/
	@echo "Done."

clean:
	rm -rf *.tar.gz luacov.*.out luacov.report.out
