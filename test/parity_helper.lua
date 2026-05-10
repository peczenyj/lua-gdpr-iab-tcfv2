local M = {}

local function format_date(deciseconds)
  local seconds = math.floor(deciseconds / 10)
  return os.date("!%Y-%m-%dT%H:%M:%SZ", seconds)
end

-- Perl JSON output only includes true values for vendor/purpose bitfields.
-- We filter out false values to match that shape exactly.
local function clean_table_to_perl_shape(t)
  if type(t) ~= "table" then
    return t
  end
  local res = {}
  local has_data = false
  for k, v in pairs(t) do
    if v == true then
      res[tostring(k)] = true
      has_data = true
    elseif type(v) == "number" then
      res[tostring(k)] = v
      has_data = true
    elseif type(v) == "table" then
      local cleaned = clean_table_to_perl_shape(v)
      if cleaned then
        res[tostring(k)] = cleaned
        has_data = true
      end
    end
  end
  return has_data and res or nil
end

function M.map_to_perl_shape(p)
  -- Instead of using p:to_table() which creates a huge intermediate structure,
  -- we map the fields directly from the lazy parser object.
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
    ) or {},
    purpose = {
      consents = clean_table_to_perl_shape(p.purposeConsents or {}) or {},
      legitimate_interests = clean_table_to_perl_shape(
        p.purposeLegitimateInterests or {}
      ) or {},
    },
    vendor = {
      consents = clean_table_to_perl_shape(p.vendorConsents or {}) or {},
      legitimate_interests = clean_table_to_perl_shape(
        p.vendorLegitimateInterests or {}
      ) or {},
    },
  }

  -- Phase 3 Mappings
  if p.vendorDisclosed then
    res.vendor.disclosed = clean_table_to_perl_shape(p.vendorDisclosed) or {}
  end
  if p.vendorAllowed then
    res.vendor.allowed = clean_table_to_perl_shape(p.vendorAllowed) or {}
  end

  local publisher = {
    restrictions = clean_table_to_perl_shape(p.publisherRestrictions or {})
      or {},
  }

  if p.pubPurposesConsent ~= nil then
    publisher.consents = clean_table_to_perl_shape(p.pubPurposesConsent) or {}
    publisher.legitimate_interests = clean_table_to_perl_shape(
      p.pubPurposesLITransparency
    ) or {}
    publisher.custom_purposes = {
      consents = clean_table_to_perl_shape(p.customPurposesConsent) or {},
      legitimate_interests = clean_table_to_perl_shape(
        p.customPurposesLITransparency
      ) or {},
    }
  end

  res.publisher = publisher
  return res
end

local function to_json_val(v)
  local t = type(v)
  if t == "string" then
    return '"' .. v .. '"'
  elseif t == "table" then
    return "{...}"
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
