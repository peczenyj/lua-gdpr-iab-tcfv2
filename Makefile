# Makefile for lua-gdpr-iab-tcfv2

# Detect Lua version from the system if not provided
LUA_BIN      ?= lua
LUA_VERSION  ?= $(shell $(LUA_BIN) -e 'print(_VERSION:match("%d+%.%d+"))' 2>/dev/null || echo 5.4)

LUA          = lua$(LUA_VERSION)
LUAROCKS     = luarocks
LUACHECK     = luacheck
STYLUA       = stylua
BUSTED       = busted
LUACOV       = luacov
GIT_CLIFF    = git-cliff

SRC_DIR      = src
DIST_NAME    = lua-gdpr-iab-tcfv2
VERSION      = 0.1.0

# Test Directories
TEST_UNITS     = test/units
TEST_REFERENCE = test/reference
TEST_FUZZ      = test/fuzz

# Local dependencies path
ROCKS_PATH   = ./.rocks
ROCKS_LUA    = $(ROCKS_PATH)/share/lua/$(LUA_VERSION)/?.lua
ROCKS_CLUA   = $(ROCKS_PATH)/lib/lua/$(LUA_VERSION)/?.so
ROCKS_BIN    = $(ROCKS_PATH)/bin

# Environment setup for local dependencies
ENV_SETUP    = export LUA_PATH="$(ROCKS_LUA);./src/?.lua;./test/?.lua;./?.lua;;" && \
               export LUA_CPATH="$(ROCKS_CLUA);;" && \
               export PATH="$(ROCKS_BIN):$$PATH"

# Verbose mode handling
ifeq ($(TCF_VERBOSE), 1)
  BUSTED_FLAGS = -o gtest
else
  BUSTED_FLAGS =
endif

.PHONY: all test test-reference test-fuzz lint format check-format coverage report-coverage changelog dist install clean setup ci task

all: test

setup:
	@echo "Detected Lua version: $(LUA_VERSION)"
	@echo "Installing development and test dependencies..."
	$(LUAROCKS) install --only-deps --tree $(ROCKS_PATH) *.rockspec
	@# Manual install of test dependencies to avoid LuaRocks bugs and missing rockspec fields
	$(LUAROCKS) install busted --tree $(ROCKS_PATH)
	$(LUAROCKS) install luacheck --tree $(ROCKS_PATH)
	$(LUAROCKS) install luacov --tree $(ROCKS_PATH)
	$(LUAROCKS) install luacov-coveralls --tree $(ROCKS_PATH)
	@echo "Dependencies installed in $(ROCKS_PATH)/"
	@echo "Note: 'stylua' must be installed manually (see DEVELOPMENT.md)"

# CI orchestrates all tests
ci: check-format lint test test-reference test-fuzz
	@echo "CI check passed successfully."

# Local development loop
task: format lint test
	@echo "Development tasks completed successfully."

# Unit tests only (Default)
test:
	@$(ENV_SETUP) && $(BUSTED) $(BUSTED_FLAGS) $(TEST_UNITS)

# Full Reference scan
test-reference:
	@$(ENV_SETUP) && $(BUSTED) $(BUSTED_FLAGS) $(TEST_REFERENCE)

# Fuzz tests
test-fuzz:
	@$(ENV_SETUP) && $(BUSTED) $(BUSTED_FLAGS) $(TEST_FUZZ)

lint:
	@$(ENV_SETUP) && $(LUACHECK) $(SRC_DIR) $(TEST_UNITS) $(TEST_REFERENCE) $(TEST_FUZZ)

format:
	@$(STYLUA) $(SRC_DIR) $(TEST_UNITS) $(TEST_REFERENCE) $(TEST_FUZZ)

check-format:
	@$(STYLUA) --check $(SRC_DIR) $(TEST_UNITS) $(TEST_REFERENCE) $(TEST_FUZZ)

coverage:
	@$(ENV_SETUP) && $(BUSTED) $(BUSTED_FLAGS) --coverage $(TEST_UNITS)
	@$(ENV_SETUP) && $(LUACOV)
	@echo "Coverage Summary:"
	@grep -A 999 "Summary" luacov.report.out || cat luacov.report.out

report-coverage:
	@$(ENV_SETUP) && luacov-coveralls -i src

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
	rm -rf *.tar.gz luacov.*.out luacov.report.out $(ROCKS_PATH)
