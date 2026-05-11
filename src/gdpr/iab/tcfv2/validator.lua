--- Policy engine for performing compliance checks on IAB TC strings.
-- @classmod gdpr.iab.tcfv2.validator
-- @author Tiago Peczenyj
-- @license MIT

local Parser = require("gdpr.iab.tcfv2.parser")

local Validator = {}
Validator.__index = Validator

-- Accept either a TC string or a pre-parsed parser table.
local function get_parser(tc_string_or_obj, options)
  if type(tc_string_or_obj) == "table" then
    return tc_string_or_obj
  end
  return Parser.new(tc_string_or_obj, options)
end

-- Enforce that a configured policy is internally consistent. Mirrors the
-- Perl reference's _check_coherence: a purpose can't appear in both
-- consent and LI lists, and any flexible entry must also appear in one of
-- those two basis lists. Called only from Validator.new; per-call
-- overrides silently drop orphan flexibles at runtime (the rule loops
-- only iterate consent/LI lists, so an orphan flex flag is unreachable).
local function check_coherence(consent, li, flexible)
  consent = consent or {}
  li = li or {}
  flexible = flexible or {}

  local consent_set, li_set = {}, {}
  for _, pid in ipairs(consent) do
    consent_set[pid] = true
  end
  for _, pid in ipairs(li) do
    li_set[pid] = true
  end

  for _, pid in ipairs(consent) do
    if li_set[pid] then
      error(
        string.format(
          "purpose %d cannot be in both consent_purpose_ids and legitimate_interest_purpose_ids",
          pid
        )
      )
    end
  end

  for _, pid in ipairs(flexible) do
    if not consent_set[pid] and not li_set[pid] then
      error(
        string.format(
          "flexible purpose %d must also appear in consent_purpose_ids or legitimate_interest_purpose_ids",
          pid
        )
      )
    end
  end
end

-- TCF spec carve-out. Purpose 1 never allows legitimate interest. Purposes
-- 3-6 lose LI starting in TCF v2.2 (policy version 4). Matches Perl's
-- _li_carve_out_applies.
local function li_carve_out_applies(pid, policy_version)
  if pid == 1 then
    return true
  end
  if pid >= 3 and pid <= 6 and (policy_version or 0) >= 4 then
    return true
  end
  return false
end

-- Validate purpose-id range. With strict_legal_basis set, an out-of-range
-- pid raises instead of being silently treated as a bitfield miss. Matches
-- the Perl parser's `strict` named argument behavior.
local function check_pid_range(pid, strict_legal_basis)
  if pid >= 1 and pid <= 24 then
    return true
  end
  if strict_legal_basis then
    error(string.format("invalid purpose id %d (must be 1..24)", pid))
  end
  return false
end

-- Merge per-call overrides on top of self.config without mutating either
-- input. Returning a fresh table preserves AGENTS.md's "no surprise
-- side-effects" contract for caller-provided tables.
local function merge_overrides(base, overrides)
  if not overrides then
    return base
  end
  local conf = {}
  for k, v in pairs(base) do
    conf[k] = v
  end
  for k, v in pairs(overrides) do
    conf[k] = v
  end
  return conf
end

--- Creates a new Validator instance with a fixed specification.
-- @function new
-- @param config table Validation rules.
-- @param[opt] config.vendor_id integer The ID of the vendor to validate.
-- @param[opt] config.consent_purpose_ids table List of purpose IDs requiring explicit consent.
-- @param[opt] config.legitimate_interest_purpose_ids table List of purpose IDs requiring legitimate interest.
-- @param[opt] config.flexible_purpose_ids table List of purpose IDs that can
--   switch legal basis. Each entry must also appear in `consent_purpose_ids`
--   or `legitimate_interest_purpose_ids`; otherwise the constructor raises.
--   Per-call overrides do not re-validate coherence: orphan flexibles in
--   an override are silently ignored at runtime.
-- @param[opt] config.verify_disclosed_vendors boolean Ensure vendor is in the
--   Disclosed Vendors segment. When the segment is present, the vendor must
--   appear there or the rule fails. When the segment is absent, behavior
--   depends on `min_tcf_policy_version`: with a floor of 5 or higher
--   (TCF v2.3+) the segment is treated as mandatory and absence fails;
--   otherwise absence is silently tolerated. Matches the Perl reference
--   implementation's gating.
-- @param[opt] config.min_tcf_policy_version integer Minimum required TCF Policy version.
-- @param[opt] config.strict_legal_basis boolean When true, an out-of-range
--   purpose ID (outside 1..24) in a configured list raises an error instead
--   of returning a quiet failure. Decoupled from the parser's strict mode.
-- @return table Validator instance.
function Validator.new(config)
  config = config or {}
  check_coherence(
    config.consent_purpose_ids,
    config.legitimate_interest_purpose_ids,
    config.flexible_purpose_ids
  )

  local self = setmetatable({}, Validator)
  self.config = config
  -- Precompute the flexible-purpose set for O(1) lookups in the hot path.
  self._flexible_set = {}
  for _, pid in ipairs(config.flexible_purpose_ids or {}) do
    self._flexible_set[pid] = true
  end
  return self
end

--- Checks if a vendor has allowed consent for a specific purpose.
-- Publisher restrictions are evaluated before the consent bitfield so the
-- failure reason names the more specific cause when both apply.
-- @function is_vendor_consent_allowed
-- @param parser table TCF Parser instance.
-- @param vendor_id integer The vendor ID.
-- @param purpose_id integer The purpose ID.
-- @param[opt] strict_legal_basis boolean Error on out-of-range purpose IDs.
-- @return boolean true if allowed.
-- @return string|nil Error message if denied.
function Validator:is_vendor_consent_allowed(
  parser,
  vendor_id,
  purpose_id,
  strict_legal_basis
)
  if not check_pid_range(purpose_id, strict_legal_basis) then
    return false,
      string.format(
        "vendor %d not allowed for purpose %d (consent)",
        vendor_id,
        purpose_id
      )
  end

  -- Publisher restrictions take precedence over the bitfield. Type 1
  -- (RequireConsent) is consistent with the consent basis -- fall through.
  local rest = parser.publisherRestrictions[purpose_id]
  if rest and rest[vendor_id] then
    local r_type = rest[vendor_id]
    if r_type == 0 then
      return false,
        string.format(
          "publisher restriction: purpose %d not allowed (vendor %d)",
          purpose_id,
          vendor_id
        )
    end
    if r_type == 2 then
      return false,
        string.format(
          "publisher restriction: purpose %d requires legitimate interest (vendor %d)",
          purpose_id,
          vendor_id
        )
    end
  end

  if
    not parser.vendorConsents[vendor_id]
    or not parser.purposeConsents[purpose_id]
  then
    return false,
      string.format(
        "vendor %d not allowed for purpose %d (consent)",
        vendor_id,
        purpose_id
      )
  end

  return true
end

--- Checks if a vendor has legitimate interest for a specific purpose.
-- Considers the TCF spec's LI carve-out (Purpose 1 always; P3-6 in v2.2+),
-- publisher restrictions, and the LI bitfield in that order.
-- @function is_vendor_legitimate_interest_allowed
-- @param parser table TCF Parser instance.
-- @param vendor_id integer The vendor ID.
-- @param purpose_id integer The purpose ID.
-- @param[opt] strict_legal_basis boolean Error on out-of-range purpose IDs.
-- @return boolean true if allowed.
-- @return string|nil Error message if denied.
function Validator:is_vendor_legitimate_interest_allowed(
  parser,
  vendor_id,
  purpose_id,
  strict_legal_basis
)
  if not check_pid_range(purpose_id, strict_legal_basis) then
    return false,
      string.format(
        "vendor %d not allowed for purpose %d (legitimate interest)",
        vendor_id,
        purpose_id
      )
  end

  if li_carve_out_applies(purpose_id, parser.policyVersion) then
    return false,
      string.format(
        "legitimate interest not permitted for purpose %d",
        purpose_id
      )
  end

  -- Publisher restrictions take precedence over the bitfield. Type 2
  -- (RequireLI) is consistent with the LI basis -- fall through.
  local rest = parser.publisherRestrictions[purpose_id]
  if rest and rest[vendor_id] then
    local r_type = rest[vendor_id]
    if r_type == 0 then
      return false,
        string.format(
          "publisher restriction: purpose %d not allowed (vendor %d)",
          purpose_id,
          vendor_id
        )
    end
    if r_type == 1 then
      return false,
        string.format(
          "publisher restriction: purpose %d requires consent (vendor %d)",
          purpose_id,
          vendor_id
        )
    end
  end

  if
    not parser.vendorLegitimateInterests[vendor_id]
    or not parser.purposeLegitimateInterests[purpose_id]
  then
    return false,
      string.format(
        "vendor %d not allowed for purpose %d (legitimate interest)",
        vendor_id,
        purpose_id
      )
  end

  return true
end

-- Shared validation loop used by both validate (fail-fast) and validate_all
-- (accumulate). Check order matches the Perl reference so the first failure
-- reported is the same in both implementations.
function Validator:_run_validation(input, stop_on_first, overrides)
  local conf = merge_overrides(self.config, overrides)

  local flexible_set
  if overrides and overrides.flexible_purpose_ids then
    flexible_set = {}
    for _, pid in ipairs(overrides.flexible_purpose_ids) do
      flexible_set[pid] = true
    end
  else
    flexible_set = self._flexible_set
  end

  -- Parser is created in its default (lenient) mode regardless of
  -- strict_legal_basis. The two flags govern unrelated concerns: parser
  -- strict mode covers structural decoding failures, strict_legal_basis
  -- covers purpose-id range validation in this validator's helpers.
  local parser, err = get_parser(input, {})
  if not parser then
    return false, { err }
  end

  local failures = {}
  local function record(msg)
    table.insert(failures, msg)
    return stop_on_first
  end

  -- 1. Vendor ID required.
  local vendor_id = conf.vendor_id
  if not vendor_id then
    if record("missing vendor_id") then
      return false, failures
    end
  end

  -- 2. Minimum TCF policy version. Fail-closed when policyVersion is nil
  -- (lenient-mode truncation): we can't verify the requirement.
  if conf.min_tcf_policy_version then
    local pv = parser.policyVersion
    if pv == nil or pv < conf.min_tcf_policy_version then
      if
        record(
          string.format(
            "TC string policy version %s is below required minimum %d",
            tostring(pv),
            conf.min_tcf_policy_version
          )
        )
      then
        return false, failures
      end
    end
  end

  -- (CMP validator deferred to a later phase.)

  -- 3. Disclosed Vendors. Gating mirrors Perl's _check_disclosed:
  -- a missing segment is only fatal when the caller has demanded
  -- min_tcf_policy_version >= 5, matching the cross-language convention.
  if conf.verify_disclosed_vendors and vendor_id then
    if parser.vendorDisclosed then
      if not parser.vendorDisclosed[vendor_id] then
        if record(string.format("vendor %d not disclosed", vendor_id)) then
          return false, failures
        end
      end
    elseif conf.min_tcf_policy_version and conf.min_tcf_policy_version >= 5 then
      if record("missing disclosed vendors segment") then
        return false, failures
      end
    end
  end

  -- 4. Consent purposes. Flexible pids flip to LI when a Type-2 restriction
  -- demands it; non-flexible pids fall through to is_vendor_consent_allowed
  -- which handles restrictions and the bitfield in spec order.
  if conf.consent_purpose_ids and vendor_id then
    for _, pid in ipairs(conf.consent_purpose_ids) do
      local rest = parser.publisherRestrictions[pid]
      local ok, v_err
      if flexible_set[pid] and rest and rest[vendor_id] == 2 then
        ok, v_err = self:is_vendor_legitimate_interest_allowed(
          parser,
          vendor_id,
          pid,
          conf.strict_legal_basis
        )
      else
        ok, v_err = self:is_vendor_consent_allowed(
          parser,
          vendor_id,
          pid,
          conf.strict_legal_basis
        )
      end
      if not ok then
        if record(v_err) then
          return false, failures
        end
      end
    end
  end

  -- 5. Legitimate-interest purposes. Symmetric to step 4 with the
  -- Type-1 restriction triggering a flip back to consent for flexible pids.
  if conf.legitimate_interest_purpose_ids and vendor_id then
    for _, pid in ipairs(conf.legitimate_interest_purpose_ids) do
      local rest = parser.publisherRestrictions[pid]
      local ok, v_err
      if flexible_set[pid] and rest and rest[vendor_id] == 1 then
        ok, v_err = self:is_vendor_consent_allowed(
          parser,
          vendor_id,
          pid,
          conf.strict_legal_basis
        )
      else
        ok, v_err = self:is_vendor_legitimate_interest_allowed(
          parser,
          vendor_id,
          pid,
          conf.strict_legal_basis
        )
      end
      if not ok then
        if record(v_err) then
          return false, failures
        end
      end
    end
  end

  if #failures > 0 then
    return false, failures
  end
  return true
end

--- Validates a TC string or object against the configured rules.
-- Returns on the first failure (fail-fast).
-- @function validate
-- @param tc_string_or_obj string|table TC string or Parser object.
-- @param[opt] overrides table Temporary overrides for this call.
-- @return boolean true if valid.
-- @return string|nil Error message on failure (first failure only).
function Validator:validate(tc_string_or_obj, overrides)
  local ok, errs = self:_run_validation(tc_string_or_obj, true, overrides)
  if ok then
    return true
  end
  return false, errs[1]
end

--- Performs all validation checks and returns every found violation.
-- @function validate_all
-- @param tc_string_or_obj string|table TC string or Parser object.
-- @param[opt] overrides table Temporary overrides for this call.
-- @return boolean true if valid.
-- @return table|nil List of error messages if invalid.
function Validator:validate_all(tc_string_or_obj, overrides)
  local ok, errs = self:_run_validation(tc_string_or_obj, false, overrides)
  if ok then
    return true
  end
  return false, errs
end

return Validator
