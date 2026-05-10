# lua-gdpr-iab-tcfv2

[![Build](https://img.shields.io/github/actions/workflow/status/peczenyj/lua-gdpr-iab-tcfv2/linux.yml?branch=devel&label=build)](https://github.com/peczenyj/lua-gdpr-iab-tcfv2/actions)
[![Linter](https://img.shields.io/badge/linter-luacheck-blue)](https://github.com/lunarmodules/luacheck)
[![Style](https://img.shields.io/badge/style-stylua-blueviolet)](https://github.com/JohnnyMorganz/StyLua)
[![License](https://img.shields.io/github/license/peczenyj/lua-gdpr-iab-tcfv2)](LICENSE)
[![Coverage Status](https://coveralls.io/repos/github/peczenyj/lua-gdpr-iab-tcfv2/badge.svg)](https://coveralls.io/github/peczenyj/lua-gdpr-iab-tcfv2)

A high-performance, zero-dependency, version-agnostic Lua parser for IAB TCF v2.x consent strings.

## Features
- **Agnostic**: Compatible with Lua 5.1, 5.2, 5.3, 5.4, and LuaJIT.
- **Middleware-ready**: Optimized for OpenResty, HAProxy, and high-concurrency environments.
- **Lazy Decoding**: Fields are decoded on-demand and cached for maximum efficiency.
- **Zero-dependency**: No external libraries required; easy to embed.
- **Parity-verified**: Tested against a comprehensive Golden Corpus for exact logical parity with existing industry-standard parsers.

## Installation
Currently in development. You can clone the repository and include the `src` directory in your `LUA_PATH`.

```bash
export LUA_PATH="./src/?.lua;;"
```

## Usage
(Example below reflects the Phase 2 implementation)

```lua
local tcf = require("gdpr.iab.tcfv2")

local parser, err = tcf.new("CP4i3...AAA")
if not parser then
    print("Error: " .. err)
    return
end
```lua
print(parser.cmpId)
print(parser.vendorConsents[284]) -- true/false
```

## Development

### First-time Setup
To set up the development environment:

1.  **Install Prerequisites**:
    - **LuaRocks**: `sudo apt install luarocks` (or `brew install luarocks`)
    - **StyLua**: Download from [GitHub Releases](https://github.com/JohnnyMorganz/StyLua/releases) and add to PATH.
2.  **Initialize Environment**:
    ```bash
    make setup
    ```

The `Makefile` automatically handles local dependencies in `.rocks/`. Use `make task` during development to format, lint, and test your changes.

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed instructions and [AGENTS.md](AGENTS.md) for technical conventions.

## License
MIT
