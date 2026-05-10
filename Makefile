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
TEST_DIR     = test
DIST_NAME    = lua-gdpr-iab-tcfv2
VERSION      = 0.1.0

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

.PHONY: all test test-quick lint format check-format coverage changelog dist install clean setup ci task

all: test

setup:
	@echo "Detected Lua version: $(LUA_VERSION)"
	@echo "Installing development and test dependencies..."
	$(LUAROCKS) install --only-deps --tree $(ROCKS_PATH) *.rockspec
	@# Manual install of test dependencies to avoid LuaRocks bugs and missing rockspec fields
	$(LUAROCKS) install busted --tree $(ROCKS_PATH)
	$(LUAROCKS) install luacheck --tree $(ROCKS_PATH)
	$(LUAROCKS) install luacov --tree $(ROCKS_PATH)
	@echo "Dependencies installed in $(ROCKS_PATH)/"
	@echo "Note: 'stylua' must be installed manually (see CONTRIBUTING.md)"
	@echo "The Makefile will now automatically use them for 'make test', 'make lint', etc."

ci: check-format lint coverage
	@echo "CI check passed successfully."

task: format lint test-quick
	@echo "Development tasks completed successfully."

test:
	@$(ENV_SETUP) && $(BUSTED) $(BUSTED_FLAGS) $(TEST_DIR)

test-quick:
	@$(ENV_SETUP) && export TCF_QUICK=1 && $(BUSTED) $(BUSTED_FLAGS) $(TEST_DIR)

lint:
	@$(ENV_SETUP) && $(LUACHECK) $(SRC_DIR) $(TEST_DIR)

format:
	@$(STYLUA) $(SRC_DIR) $(TEST_DIR)

check-format:
	@$(STYLUA) --check $(SRC_DIR) $(TEST_DIR)

coverage:
	@$(ENV_SETUP) && $(BUSTED) $(BUSTED_FLAGS) --coverage $(TEST_DIR)
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
	@cp src/gdpr/iab/tcfv2/*.lua /usr/local/share/lua/$(LUA_VERSION)/gdpr/iab/tcfv2/
	@echo "Done."

clean:
	rm -rf *.tar.gz luacov.*.out luacov.report.out $(ROCKS_PATH)
