local tcf = require("gdpr.iab.tcfv2")

local Validator = {}
Validator.__index = Validator

function Validator.new(config)
  local self = setmetatable({}, Validator)
  self.config = config or {}
  return self
end

local function get_parser(tc_string_or_obj, options)
  if type(tc_string_or_obj) == "table" then
    return tc_string_or_obj
  end
  return tcf.new(tc_string_or_obj, options)
end

function Validator:validate(tc_string_or_obj, overrides)
  local conf = self.config
  if overrides then
    conf = setmetatable(overrides, { __index = self.config })
  end

  local parser, err =
    get_parser(tc_string_or_obj, { strict = conf.strict_legal_basis })
  if not parser then
    return false, err
  end

  local vendor_id = conf.vendor_id
  if not vendor_id then
    return false, "missing vendor_id"
  end

  -- 1. Min TCF Policy Version Check
  if
    conf.min_tcf_policy_version
    and parser.policyVersion < conf.min_tcf_policy_version
  then
    return false,
      string.format(
        "policy version %d is less than required %d",
        parser.policyVersion,
        conf.min_tcf_policy_version
      )
  end

  -- 2. Consent Purpose Checks
  if conf.consent_purpose_ids then
    -- Per Perl logic: first check if Vendor has consent at all
    if not parser.vendorConsents[vendor_id] then
      return false, string.format("missing consent for vendor %d", vendor_id)
    end

    for _, pid in ipairs(conf.consent_purpose_ids) do
      if not parser.purposeConsents[pid] then
        return false, string.format("missing consent for purpose %d", pid)
      end
      -- Check Publisher Restrictions (Type 0 = Not Allowed)
      local rest = parser.publisherRestrictions[vendor_id]
      if rest and rest[pid] and rest[pid][0] then
        return false,
          string.format(
            "purpose %d is restricted for vendor %d",
            pid,
            vendor_id
          )
      end
    end
  end

  -- 3. Legitimate Interest Checks
  if conf.legitimate_interest_purpose_ids then
    if not parser.vendorLegitimateInterests[vendor_id] then
      return false,
        string.format("missing legitimate interest for vendor %d", vendor_id)
    end

    for _, pid in ipairs(conf.legitimate_interest_purpose_ids) do
      -- Purpose 1 never allows LI
      if pid == 1 then
        return false, "purpose 1 does not allow legitimate interest"
      end
      if not parser.purposeLegitimateInterests[pid] then
        return false,
          string.format("missing legitimate interest for purpose %d", pid)
      end
    end
  end

  -- 4. Disclosed Vendors Check
  if conf.verify_disclosed_vendors then
    if parser.vendorDisclosed then
      if not parser.vendorDisclosed[vendor_id] then
        return false,
          string.format("vendor %d not in disclosed vendors segment", vendor_id)
      end
    elseif conf.min_tcf_policy_version and conf.min_tcf_policy_version >= 5 then
      return false,
        "missing mandatory disclosed vendors segment for policy v2.3+"
    end
  end

  return true
end

function Validator:validate_all(tc_string_or_obj, overrides)
  local errors = {}
  -- Placeholder for full accumulation logic
  local ok, err = self:validate(tc_string_or_obj, overrides)
  if not ok then
    table.insert(errors, err)
    return false, errors
  end
  return true
end

return Validator
