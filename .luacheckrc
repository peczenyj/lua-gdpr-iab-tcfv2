# Luacheck configuration
# See: https://luacheck.readthedocs.io/en/stable/config.html

# Global settings
std = "lua51+lua52+lua53+lua54+luajit"
unused_args = false
redefined = false

# Ignore specific warnings
ignore = {
    "611", # line contains only whitespace
}

# Per-file overrides
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
    }
}
