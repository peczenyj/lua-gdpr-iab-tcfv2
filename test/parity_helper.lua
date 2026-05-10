local M = {}

local function format_date(deciseconds)
  local seconds = math.floor(deciseconds / 10)
  return os.date("!%Y-%m-%dT%H:%M:%SZ", seconds)
end

-- Perl JSON output only includes true values for vendor/purpose bitfields.
-- We filter out false values to match that shape exactly.
-- Restrictions use numeric values (1, 2, 3).
local function clean_table_to_perl_shape(t)
  if type(t) ~= "table" then
    return t
  end
  local res = {}
  local is_empty = true
  for k, v in pairs(t) do
    if v == true then
      res[tostring(k)] = true
      is_empty = false
    elseif type(v) == "number" then
      res[tostring(k)] = v
      is_empty = false
    elseif type(v) == "table" then
      local cleaned = clean_table_to_perl_shape(v)
      if cleaned then
        res[tostring(k)] = cleaned
        is_empty = false
      end
    end
  end
  if is_empty then
    return {}
  end
  return res
end

function M.map_to_perl_shape(p)
  local res = {
    version = p.version,
    created = format_date(p.created),
    last_updated = format_date(p.lastUpdated),
    cmp_id = p.cmpId,
    cmp_version = p.cmpVersion,
    consent_screen = p.consentScreen,
    consent_language = p.consentLanguage,
    vendor_list_version = p.vendorListVersion,
    policy_version = p.policyVersion,
    is_service_specific = p.isServiceSpecific,
    use_non_standard_stacks = p.useNonStandardStacks,
    purpose_one_treatment = p.purposeOneTreatment,
    publisher_country_code = p.publisherCountryCode,
    tc_string = p.tc_string,

    special_features_opt_in = clean_table_to_perl_shape(
      p.specialFeaturesOptIn or {}
    ),
    purpose = {
      consents = clean_table_to_perl_shape(p.purposeConsents or {}),
      legitimate_interests = clean_table_to_perl_shape(
        p.purposeLegitimateInterests or {}
      ),
    },
    vendor = {
      consents = clean_table_to_perl_shape(p.vendorConsents or {}),
      legitimate_interests = clean_table_to_perl_shape(
        p.vendorLegitimateInterests or {}
      ),
    },
    publisher = {
      consents = clean_table_to_perl_shape(p.pubPurposesConsent or {}),
      legitimate_interests = clean_table_to_perl_shape(
        p.pubPurposesLITransparency or {}
      ),
      restrictions = clean_table_to_perl_shape(p.publisherRestrictions or {}),
      custom_purposes = {
        consents = clean_table_to_perl_shape(p.customPurposesConsent or {}),
        legitimate_interests = clean_table_to_perl_shape(
          p.customPurposesLITransparency or {}
        ),
      },
    },
  }

  return res
end

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
      -- Perl JSON might omit false values, but we already cleaned them.
      -- If it's in actual, it should be in expected.
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
