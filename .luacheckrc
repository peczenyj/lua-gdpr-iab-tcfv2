-- Luacheck configuration
-- See: https://luacheck.readthedocs.io/en/stable/config.html

-- Global settings.
-- The union below is functionally equivalent to "max" and accepts globals
-- valid in any of the listed runtimes. Lua 5.5 is intentionally omitted:
-- luacheck 1.2.0 doesn't ship a "lua55" std definition, and the project
-- doesn't currently rely on 5.5-specific globals.
std = "lua51+lua52+lua53+lua54+luajit"
unused_args = false
redefined = false

-- Ignore specific warnings
ignore = {
  "611", -- line contains only whitespace
}

-- Per-file overrides
files["test/*.lua"] = {
  globals = {
    "describe",
    "it",
    "before_each",
    "after_each",
    "setup",
    "teardown",
    "assert",
    "stub",
    "spy",
    "match",
  },
}
