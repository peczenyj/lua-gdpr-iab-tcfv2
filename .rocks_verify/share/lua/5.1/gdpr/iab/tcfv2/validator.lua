--- Policy engine for performing compliance checks on IAB TC strings.
-- @classmod gdpr.iab.tcfv2.validator
-- @author Tiago Peczenyj
-- @license MIT

local Parser = require("gdpr.iab.tcfv2.parser")

local Validator = {}
Validator.__index = Validator

--- Creates a new Validator instance with a fixed specification.
-- @function new
-- @param config table Validation rules.
-- @param[opt] config.vendor_id integer The ID of the vendor to validate.
-- @param[opt] config.consent_purpose_ids table List of purpose IDs requiring explicit consent.
-- @param[opt] config.legitimate_interest_purpose_ids table List of purpose IDs requiring legitimate interest.
-- @param[opt] config.flexible_purpose_ids table List of purpose IDs that can switch legal basis.
-- @param[opt] config.verify_disclosed_vendors boolean Ensure vendor is in the Disclosed Vendors segment.
-- @param[opt] config.min_tcf_policy_version integer Minimum required TCF Policy version.
-- @param[opt] config.strict_legal_basis boolean Throw error on invalid purpose combinations.
-- @return table Validator instance.
function Validator.new(config)
  local self = setmetatable({}, Validator)
  self.config = config or {}
  return self
end

local function get_parser(tc_string_or_obj, options)
  if type(tc_string_or_obj) == "table" then
    return tc_string_or_obj
  end
  return Parser.new(tc_string_or_obj, options)
end

local function is_in_table(val, tbl)
  if not tbl then
    return false
  end
  for _, v in ipairs(tbl) do
    if v == val then
      return true
    end
  end
  return false
end

--- Checks if a vendor has allowed consent for a specific purpose.
-- Considers both standard consent and publisher restrictions.
-- @function is_vendor_consent_allowed
-- @param parser table TCF Parser instance.
-- @param vendor_id integer The vendor ID.
-- @param purpose_id integer The purpose ID.
-- @return boolean true if allowed.
-- @return string|nil Error message if denied.
function Validator:is_vendor_consent_allowed(parser, vendor_id, purpose_id)
  if not parser.vendorConsents[vendor_id] then
    return false, string.format("missing consent for vendor %d", vendor_id)
  end
  if not parser.purposeConsents[purpose_id] then
    return false, string.format("missing consent for purpose %d", purpose_id)
  end

  -- Publisher Restrictions shape: [purpose_id][vendor_id] = restriction_type
  local rest = parser.publisherRestrictions[purpose_id]
  if rest and rest[vendor_id] then
    local r_type = rest[vendor_id]
    if r_type == 0 then
      return false,
        string.format(
          "purpose %d is restricted for vendor %d",
          purpose_id,
          vendor_id
        )
    end
    if r_type == 2 then
      return false,
        string.format(
          "purpose %d requires legitimate interest for vendor %d",
          purpose_id,
          vendor_id
        )
    end
  end
  return true
end

--- Checks if a vendor has legitimate interest for a specific purpose.
-- Considers both standard LI and publisher restrictions.
-- @function is_vendor_legitimate_interest_allowed
-- @param parser table TCF Parser instance.
-- @param vendor_id integer The vendor ID.
-- @param purpose_id integer The purpose ID.
-- @return boolean true if allowed.
-- @return string|nil Error message if denied.
function Validator:is_vendor_legitimate_interest_allowed(
  parser,
  vendor_id,
  purpose_id
)
  if purpose_id == 1 then
    return false, "purpose 1 does not allow legitimate interest"
  end
  if not parser.vendorLegitimateInterests[vendor_id] then
    return false,
      string.format("missing legitimate interest for vendor %d", vendor_id)
  end
  if not parser.purposeLegitimateInterests[purpose_id] then
    return false,
      string.format("missing legitimate interest for purpose %d", purpose_id)
  end

  -- Publisher Restrictions shape: [purpose_id][vendor_id] = restriction_type
  local rest = parser.publisherRestrictions[purpose_id]
  if rest and rest[vendor_id] then
    local r_type = rest[vendor_id]
    if r_type == 0 then
      return false,
        string.format(
          "purpose %d is restricted for vendor %d",
          purpose_id,
          vendor_id
        )
    end
    if r_type == 1 then
      return false,
        string.format(
          "purpose %d requires consent for vendor %d",
          purpose_id,
          vendor_id
        )
    end
  end
  return true
end

--- Validates a TC string or object against the configured rules.
-- Returns on the first failure (fail-fast).
-- @function validate
-- @param tc_string_or_obj string|table TC string or Parser object.
-- @param[opt] overrides table Temporary overrides for this call.
-- @return boolean true if valid.
-- @return string|nil Error message on failure.
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
    for _, pid in ipairs(conf.consent_purpose_ids) do
      local ok, v_err
      -- If flexible, we might switch to LI if restricted to Require LI (Type 2)
      local rest = parser.publisherRestrictions[pid]
      if
        is_in_table(pid, conf.flexible_purpose_ids)
        and rest
        and rest[vendor_id] == 2
      then
        ok, v_err =
          self:is_vendor_legitimate_interest_allowed(parser, vendor_id, pid)
      else
        ok, v_err = self:is_vendor_consent_allowed(parser, vendor_id, pid)
      end

      if not ok then
        return false,
          v_err or string.format(
            "vendor %d not allowed for purpose %d (consent)",
            vendor_id,
            pid
          )
      end
    end
  end

  -- 3. Legitimate Interest Checks
  if conf.legitimate_interest_purpose_ids then
    for _, pid in ipairs(conf.legitimate_interest_purpose_ids) do
      local ok, v_err
      -- If flexible, we might switch to Consent if restricted to Require Consent (Type 1)
      local rest = parser.publisherRestrictions[pid]
      if
        is_in_table(pid, conf.flexible_purpose_ids)
        and rest
        and rest[vendor_id] == 1
      then
        ok, v_err = self:is_vendor_consent_allowed(parser, vendor_id, pid)
      else
        ok, v_err =
          self:is_vendor_legitimate_interest_allowed(parser, vendor_id, pid)
      end

      if not ok then
        return false,
          v_err or string.format(
            "vendor %d not allowed for purpose %d (li)",
            vendor_id,
            pid
          )
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

--- Performs all validation checks and returns all found violations.
-- @function validate_all
-- @param tc_string_or_obj string|table TC string or Parser object.
-- @param[opt] overrides table Temporary overrides for this call.
-- @return boolean true if valid.
-- @return table|nil List of error messages if invalid.
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
