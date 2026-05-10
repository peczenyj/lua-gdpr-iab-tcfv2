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

  -- Route other segments
  local other_segments, r_err = Router.decode_segments(segments, options)
  if not other_segments then
    return nil, r_err
  end

  -- We use a proxy metatable to expose Core fields directly on the Parser object.
  local parser = setmetatable({
    _core = core,
    _segments = segments,
    _other = other_segments,
  }, {
    __index = function(tbl, key)
      if key == "tc_string" then
        return tbl._core.tc_string
      end
      if key == "warnings" then
        return tbl._core.warnings
      end

      -- Check other segments
      if tbl._other[1] and tbl._other[1][key] ~= nil then
        return tbl._other[1][key]
      end
      if tbl._other[2] and tbl._other[2][key] ~= nil then
        return tbl._other[2][key]
      end
      if tbl._other[3] and tbl._other[3][key] ~= nil then
        return tbl._other[3][key]
      end

      -- Delegate to Core
      local val = tbl._core[key]
      if val ~= nil then
        return val
      end

      if key == "to_table" then
        return function(p)
          local res = p._core:to_table()
          for _, seg in pairs(p._other) do
            for k, v in pairs(seg) do
              res[k] = v
            end
          end
          return res
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
