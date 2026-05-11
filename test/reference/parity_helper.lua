local M = {}

local function to_json_val(v)
  if type(v) == "string" then
    return '"' .. v .. '"'
  end
  if type(v) == "table" then
    local pieces = {}
    for k, val in pairs(v) do
      table.insert(pieces, tostring(k) .. "=" .. to_json_val(val))
    end
    return "{" .. table.concat(pieces, ",") .. "}"
  end
  return tostring(v)
end

function M.deep_compare(actual, expected, path)
  path = path or "root"

  if
    expected == nil
    and (actual == nil or (type(actual) == "table" and next(actual) == nil))
  then
    return true
  end

  if type(actual) ~= type(expected) then
    return false,
      string.format(
        "%s: type mismatch (%s vs %s)",
        path,
        type(actual),
        type(expected)
      )
  end

  if type(actual) ~= "table" then
    if actual ~= expected then
      return false,
        string.format(
          "%s: value mismatch (%s vs %s)",
          path,
          to_json_val(actual),
          to_json_val(expected)
        )
    end
    return true
  end

  -- Check all keys in actual exist and match in expected
  for k, v in pairs(actual) do
    local ek = tostring(k)
    if expected[ek] == nil then
      return false,
        string.format("%s: unexpected key in actual result", path .. "." .. ek)
    end
    local ok, err = M.deep_compare(v, expected[ek], path .. "." .. ek)
    if not ok then
      return false, err
    end
  end

  -- Check all keys in expected exist in actual
  for k, _ in pairs(expected) do
    local ek = tostring(k)
    local ak = tonumber(k) or k
    if actual[k] == nil and actual[ek] == nil and actual[ak] == nil then
      return false,
        string.format("%s: missing key in actual result", path .. "." .. ek)
    end
  end

  return true
end

return M
