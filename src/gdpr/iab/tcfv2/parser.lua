--- Parser factory for creating unified TCF objects.
-- @module gdpr.iab.tcfv2.parser
-- @author Tiago Peczenyj
-- @license MIT

local base64 = require("gdpr.iab.tcfv2.base64")
local Core = require("gdpr.iab.tcfv2.core")
local Router = require("gdpr.iab.tcfv2.router")

local M = {}

local function split(input, sep)
  local t = {}
  for str in string.gmatch(input, "([^" .. sep .. "]+)") do
    table.insert(t, str)
  end
  return t
end

--- Creates a new TCF Parser instance from a TC string.
-- @function new
-- @param tc_string string The encoded IAB TCF v2.x consent string.
-- @param[opt] options table Configuration options.
-- @param[opt] options.strict boolean Enable strict decoding mode.
-- @param[opt] options.targetVendors table List of vendor IDs to optimize decoding for.
-- @return table|nil Parser object or nil on error.
-- @return string|nil Error message if parsing failed.
function M.new(tc_string, options)
  if not tc_string or tc_string == "" then
    return nil, "missing gdpr consent string"
  end

  options = options or {}

  -- In strict mode, a TC string with empty segments (leading/trailing dot
  -- or consecutive dots) is malformed by structure. Lenient mode still
  -- accepts and silently drops empties via the gmatch in split().
  if options.strict then
    if
      tc_string:find("%.%.")
      or tc_string:sub(1, 1) == "."
      or tc_string:sub(-1) == "."
    then
      return nil, "malformed tc string: empty segment"
    end
  end

  local segments = split(tc_string, "%.")

  -- Decode Core segment
  local core_b64 = segments[1]
  local core_data, err = base64.decode_url(core_b64)
  if not core_data then
    return nil, "invalid base64 in core segment: " .. tostring(err)
  end

  -- Initialize Core object
  local core = Core.new(core_data, options)
  core.tc_string = tc_string

  -- Basic validation
  if options.strict then
    if core.version ~= 2 then
      return nil, "consent string is not tcf version 2"
    end
    if core.vendorListVersion == 0 then
      return nil, "invalid vendor list version"
    end
  end

  -- Route other segments. Pass core.warnings so the router can append
  -- lenient-mode segment failures to the unified parser.warnings aggregate.
  local other_segments, r_err =
    Router.decode_segments(segments, options, core.warnings)
  if not other_segments then
    return nil, r_err
  end

  -- We use a proxy metatable to expose Core fields directly on the Parser object.
  local parser = {
    _core = core,
    _segments = segments,
    _other = other_segments,
  }

  --- Converts the entire parser state to a plain Lua table.
  -- Includes fields from all decoded segments.
  -- @function to_table
  -- @return table
  function parser:to_table()
    local res = self._core:to_table()
    for _, seg in pairs(self._other) do
      if seg.to_table then
        local st = seg:to_table()
        for k, v in pairs(st) do
          res[k] = v
        end
      end
    end
    return res
  end

  setmetatable(parser, {
    __index = function(tbl, key)
      if key == "tc_string" then
        return tbl._core.tc_string
      end
      if key == "warnings" then
        return tbl._core.warnings
      end

      -- Check other segments for direct field access
      for _, seg in pairs(tbl._other) do
        if seg[key] ~= nil then
          return seg[key]
        end
      end

      -- Delegate to Core
      local val = tbl._core[key]
      if val ~= nil then
        return val
      end

      -- Predicates derived from policyVersion. In lenient mode policyVersion
      -- can be nil if the core segment is truncated; treat that as "not >=".
      if key == "is_v22_plus" then
        local pv = tbl._core.policyVersion
        return pv ~= nil and pv >= 4
      end

      if key == "is_v23" then
        local pv = tbl._core.policyVersion
        return pv ~= nil and pv >= 5
      end

      return nil
    end,
  })

  return parser
end

return M
