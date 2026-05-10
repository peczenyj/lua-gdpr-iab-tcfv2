local base64 = require("gdpr.iab.tcfv2.base64")
local Core = require("gdpr.iab.tcfv2.core")

local M = {}

local function split(input, sep)
  local t = {}
  for str in string.gmatch(input, "([^" .. sep .. "]+)") do
    table.insert(t, str)
  end
  return t
end

function M.new(tc_string, options)
  if not tc_string or tc_string == "" then
    return nil, "missing gdpr consent string"
  end

  options = options or {}
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

  -- Phase 3 will handle other segments. For now, we just route the Core segment.
  -- We use a proxy metatable to expose Core fields directly on the Parser object.
  local parser = setmetatable({
    _core = core,
    _segments = segments,
  }, {
    __index = function(tbl, key)
      if key == "tc_string" then
        return tbl._core.tc_string
      end
      if key == "warnings" then
        return tbl._core.warnings
      end

      -- Delegate to Core
      local val = tbl._core[key]
      if val ~= nil then
        return val
      end

      if key == "to_table" then
        return function(p)
          return p._core:to_table()
        end
      end

      if key == "is_v22_plus" then
        return tbl._core.policyVersion >= 4
      end

      if key == "is_v23" then
        return tbl._core.policyVersion >= 5
      end

      return M[key]
    end,
  })

  return parser
end

return M
