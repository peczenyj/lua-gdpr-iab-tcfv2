--- Policy engine for performing compliance checks on IAB TC strings.
-- @classmod gdpr.iab.tcfv2.validator
-- @author Tiago Peczenyj
-- @license MIT

local Parser = require("gdpr.iab.tcfv2.parser")

local Validator = {}
Validator.__index = Validator

-- Publisher RestrictionType constants (TCF spec).
local NOT_ALLOWED = 0
local REQUIRE_CONSENT = 1
local REQUIRE_LI = 2

-- TCF v2.3 became mandatory on 2026-02-28T00:00:00Z. Strings created strictly
-- after this instant must use policy version >= 5 and carry a disclosed-vendors
-- segment. The value is in DECISECONDS to match parser.created (the raw 36-bit
-- TCF Created field); the strictly-after comparison mirrors the Go validator's
-- created.After(v23Deadline) and the Perl reference (note: the parser's is_v23
-- uses >= for its own gate; the Validator deliberately matches Go here).
local TCF_V23_DEADLINE = 17722368000 -- 1772236800 seconds * 10

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

-- True when the TC string carries publisher restriction `rtype` for the
-- (purpose, vendor) pair. Mirrors Perl's check_publisher_restriction.
local function check_publisher_restriction(parser, pid, rtype, vendor_id)
  local rest = parser.publisherRestrictions[pid]
  return rest ~= nil and rest[vendor_id] == rtype
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
--   appear there or the rule fails. An absent segment is never a
--   verify_disclosed_vendors failure on its own -- that case is owned by the
--   mandatory-segment rules (see below). Setting `min_tcf_policy_version` to
--   5 or higher implies this flag (it is auto-enabled), mirroring the Go
--   lib-gdpr validator.
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

  -- Shallow-copy so the auto-enable below never mutates the caller's table.
  local cfg = {}
  for k, v in pairs(config) do
    cfg[k] = v
  end

  -- A policy floor of v2.3+ (>= 5) makes the disclosed-vendors segment
  -- mandatory, so verifying it is implied. Mirrors the Go validator's
  -- verifyDisclosedVendors = cfg.VerifyDisclosedVendors || cfg.MinTcfPolicyVersion >= 5.
  if
    not cfg.verify_disclosed_vendors
    and cfg.min_tcf_policy_version
    and cfg.min_tcf_policy_version >= 5
  then
    cfg.verify_disclosed_vendors = true
  end

  local self = setmetatable({}, Validator)
  self.config = cfg
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
    if r_type == NOT_ALLOWED then
      return false,
        string.format(
          "publisher restriction: purpose %d not allowed (vendor %d)",
          purpose_id,
          vendor_id
        )
    end
    if r_type == REQUIRE_LI then
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
    if r_type == NOT_ALLOWED then
      return false,
        string.format(
          "publisher restriction: purpose %d not allowed (vendor %d)",
          purpose_id,
          vendor_id
        )
    end
    if r_type == REQUIRE_CONSENT then
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

--- Resolves a flexible purpose to its effective legal basis and checks it.
-- Mirrors the Perl parser's is_vendor_allowed_for_flexible_purpose (and the
-- Go validator's runFlexibleCheck): a publisher restriction selects the
-- basis (RequireConsent => consent, RequireLI => LI, NotAllowed => deny),
-- otherwise the structural default applies, after the spec carve-out has
-- forced consent for Purpose 1 / Purposes 3-6 (v2.2+).
-- @return boolean true if allowed under the effective basis.
function Validator:is_vendor_allowed_for_flexible_purpose(
  parser,
  vendor_id,
  purpose_id,
  default_is_li,
  strict_legal_basis
)
  if not check_pid_range(purpose_id, strict_legal_basis) then
    return false
  end

  -- Spec carve-out forces the consent default (it does not deny outright;
  -- the bitfield check below still decides).
  if li_carve_out_applies(purpose_id, parser.policyVersion) then
    default_is_li = false
  end

  if
    check_publisher_restriction(parser, purpose_id, REQUIRE_CONSENT, vendor_id)
  then
    return (
      self:is_vendor_consent_allowed(
        parser,
        vendor_id,
        purpose_id,
        strict_legal_basis
      )
    )
  end

  if check_publisher_restriction(parser, purpose_id, REQUIRE_LI, vendor_id) then
    return (
      self:is_vendor_legitimate_interest_allowed(
        parser,
        vendor_id,
        purpose_id,
        strict_legal_basis
      )
    )
  end

  if
    check_publisher_restriction(parser, purpose_id, NOT_ALLOWED, vendor_id)
  then
    return false
  end

  if default_is_li then
    return (
      self:is_vendor_legitimate_interest_allowed(
        parser,
        vendor_id,
        purpose_id,
        strict_legal_basis
      )
    )
  end

  return (
    self:is_vendor_consent_allowed(
      parser,
      vendor_id,
      purpose_id,
      strict_legal_basis
    )
  )
end

-- Inspect publisher restrictions for (vendor, pid) on a non-flexible purpose
-- and return a failure message when a restriction contradicts the configured
-- basis, or nil otherwise. basis: 0 = consent, 1 = legitimate interest.
-- A NotAllowed restriction always wins; otherwise only the contradicting
-- Require* type is reported (the matching one is a legal coexistence).
-- Mirrors Perl's _publisher_restriction_failure.
local function publisher_restriction_failure(parser, vendor_id, pid, basis)
  if check_publisher_restriction(parser, pid, NOT_ALLOWED, vendor_id) then
    return string.format(
      "publisher restriction: purpose %d not allowed (vendor %d)",
      pid,
      vendor_id
    )
  end
  if
    basis == 0
    and check_publisher_restriction(parser, pid, REQUIRE_LI, vendor_id)
  then
    return string.format(
      "publisher restriction: purpose %d requires legitimate interest (vendor %d)",
      pid,
      vendor_id
    )
  end
  if
    basis == 1
    and check_publisher_restriction(parser, pid, REQUIRE_CONSENT, vendor_id)
  then
    return string.format(
      "publisher restriction: purpose %d requires consent (vendor %d)",
      pid,
      vendor_id
    )
  end
  return nil
end

-- Build the failure message for a flexible purpose the parser rejected,
-- mirroring the Go validator's runFlexibleCheck reason selection (and Perl's
-- _flexible_failure). NotAllowed wins outright; otherwise the effective basis
-- decides -- a spec carve-out forces consent, then a Require* restriction
-- overrides; on the LI basis the carve-out still outranks the generic LI
-- failure.
local function flexible_failure(parser, vendor_id, pid, default_is_li)
  if check_publisher_restriction(parser, pid, NOT_ALLOWED, vendor_id) then
    return string.format(
      "publisher restriction: purpose %d not allowed (vendor %d)",
      pid,
      vendor_id
    )
  end

  local is_li = default_is_li
  if li_carve_out_applies(pid, parser.policyVersion) then
    is_li = false
  end

  if check_publisher_restriction(parser, pid, REQUIRE_CONSENT, vendor_id) then
    is_li = false
  elseif check_publisher_restriction(parser, pid, REQUIRE_LI, vendor_id) then
    is_li = true
  end

  if is_li and li_carve_out_applies(pid, parser.policyVersion) then
    return string.format(
      "legitimate interest not permitted for purpose %d",
      pid
    )
  end

  if is_li then
    return string.format(
      "vendor %d not allowed for purpose %d (legitimate interest)",
      vendor_id,
      pid
    )
  end
  return string.format(
    "vendor %d not allowed for purpose %d (consent)",
    vendor_id,
    pid
  )
end

-- Single policy-version gate mirroring the Go validator's
-- yieldPolicyVersionFailure / Perl's _check_policy_version: the date-based
-- v2.3 rule takes precedence, then the explicit floor. At most one failure is
-- emitted. A nil policy version (lenient-mode truncation) is treated as below
-- any requirement (fail-closed).
function Validator:_check_policy_version(
  parser,
  min_tcf_policy_version,
  failures
)
  local actual = parser.policyVersion

  if
    parser.created
    and parser.created > TCF_V23_DEADLINE
    and (actual == nil or actual < 5)
  then
    table.insert(failures, "post-deadline string requires policy version >= 5")
    return
  end

  if
    min_tcf_policy_version
    and (actual == nil or actual < min_tcf_policy_version)
  then
    table.insert(
      failures,
      string.format(
        "TC string policy version %s is below required minimum %d",
        tostring(actual),
        min_tcf_policy_version
      )
    )
  end
end

-- Disclosed-vendors gate mirroring Perl's _check_disclosed / the Go validator's
-- yieldMandatoryDisclosedVendors. The mandatory-segment check runs regardless
-- of verify_disclosed and may fire on either ground (both, when they overlap):
--   (a) any string created strictly after the v2.3 deadline;
--   (b) a policy>=5 string under a policy>=5 floor.
-- The verify branch only applies when the segment is present (an absent segment
-- is owned by the mandatory check, never here -- matching Go).
function Validator:_check_disclosed(
  parser,
  vendor_id,
  verify_disclosed,
  min_tcf_policy_version,
  failures
)
  local has_disclosure = parser.vendorDisclosed ~= nil

  if not has_disclosure then
    if parser.created and parser.created > TCF_V23_DEADLINE then
      table.insert(
        failures,
        "post-deadline string requires disclosed vendors segment"
      )
    end

    local pv = parser.policyVersion
    if
      pv
      and pv >= 5
      and min_tcf_policy_version
      and min_tcf_policy_version >= 5
    then
      table.insert(failures, "missing disclosed vendors segment")
    end
  end

  if
    verify_disclosed
    and has_disclosure
    and not parser.vendorDisclosed[vendor_id]
  then
    table.insert(failures, string.format("vendor %d not disclosed", vendor_id))
  end
end

-- Global vendor gate mirroring the Go validator (ReasonVendorNotAllowed) and
-- the Perl _check_vendor_gate: a vendor with neither vendor-level consent nor
-- legitimate interest can never satisfy any per-purpose check. Returns true
-- when the gate fires (the caller short-circuits in both modes).
function Validator:_check_vendor_gate(parser, vendor_id, failures)
  if parser.vendorConsents[vendor_id] then
    return false
  end
  if parser.vendorLegitimateInterests[vendor_id] then
    return false
  end

  table.insert(
    failures,
    string.format(
      "vendor %d not allowed (no consent or legitimate interest)",
      vendor_id
    )
  )
  return true
end

-- Consent-purpose loop. Flexible pids resolve their effective basis via
-- is_vendor_allowed_for_flexible_purpose; non-flexible pids report a
-- restriction contradiction before falling through to the bitfield check.
function Validator:_check_consent_purposes(
  parser,
  vendor_id,
  strict_legal_basis,
  failures,
  stop_on_first,
  consent_ids,
  flexible_set
)
  for _, pid in ipairs(consent_ids or {}) do
    local is_flexible = flexible_set[pid]

    local pr
    if not is_flexible then
      pr = publisher_restriction_failure(parser, vendor_id, pid, 0)
    end

    if pr then
      table.insert(failures, pr)
      if stop_on_first then
        return
      end
    else
      local allowed
      if is_flexible then
        allowed = self:is_vendor_allowed_for_flexible_purpose(
          parser,
          vendor_id,
          pid,
          false,
          strict_legal_basis
        )
      else
        allowed = self:is_vendor_consent_allowed(
          parser,
          vendor_id,
          pid,
          strict_legal_basis
        )
      end

      if not allowed then
        if is_flexible then
          table.insert(
            failures,
            flexible_failure(parser, vendor_id, pid, false)
          )
        else
          table.insert(
            failures,
            string.format(
              "vendor %d not allowed for purpose %d (consent)",
              vendor_id,
              pid
            )
          )
        end
        if stop_on_first then
          return
        end
      end
    end
  end
end

-- Legitimate-interest-purpose loop. Symmetric to the consent loop, with the
-- spec carve-out reported up front for non-flexible pids.
function Validator:_check_li_purposes(
  parser,
  vendor_id,
  strict_legal_basis,
  failures,
  stop_on_first,
  li_ids,
  flexible_set
)
  local policy_version = parser.policyVersion

  for _, pid in ipairs(li_ids or {}) do
    local is_flexible = flexible_set[pid]

    if not is_flexible and li_carve_out_applies(pid, policy_version) then
      table.insert(
        failures,
        string.format("legitimate interest not permitted for purpose %d", pid)
      )
      if stop_on_first then
        return
      end
    else
      local pr
      if not is_flexible then
        pr = publisher_restriction_failure(parser, vendor_id, pid, 1)
      end

      if pr then
        table.insert(failures, pr)
        if stop_on_first then
          return
        end
      else
        local allowed
        if is_flexible then
          allowed = self:is_vendor_allowed_for_flexible_purpose(
            parser,
            vendor_id,
            pid,
            true,
            strict_legal_basis
          )
        else
          allowed = self:is_vendor_legitimate_interest_allowed(
            parser,
            vendor_id,
            pid,
            strict_legal_basis
          )
        end

        if not allowed then
          if is_flexible then
            table.insert(
              failures,
              flexible_failure(parser, vendor_id, pid, true)
            )
          else
            table.insert(
              failures,
              string.format(
                "vendor %d not allowed for purpose %d (legitimate interest)",
                vendor_id,
                pid
              )
            )
          end
          if stop_on_first then
            return
          end
        end
      end
    end
  end
end

-- Shared validation loop used by both validate (fail-fast) and validate_all
-- (accumulate). Check order matches the Perl reference (policy version,
-- disclosed vendors, vendor gate, consent purposes, LI purposes) so the first
-- failure reported is the same in both implementations.
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

  -- 1. Minimum / v2.3 policy version. Independent of vendor_id.
  self:_check_policy_version(parser, conf.min_tcf_policy_version, failures)
  if stop_on_first and #failures > 0 then
    return false, failures
  end

  -- 2. Vendor ID required for every vendor-scoped rule below.
  local vendor_id = conf.vendor_id
  if not vendor_id then
    table.insert(failures, "missing vendor_id")
    return false, failures
  end

  -- (CMP validator deferred to a later phase.)

  -- 3. Disclosed Vendors. Runs before the vendor gate so a "not disclosed"
  -- failure is reported ahead of the more generic gate failure.
  self:_check_disclosed(
    parser,
    vendor_id,
    conf.verify_disclosed_vendors,
    conf.min_tcf_policy_version,
    failures
  )
  if stop_on_first and #failures > 0 then
    return false, failures
  end

  -- 4. Global vendor gate. A vendor with neither consent nor legitimate
  -- interest can never satisfy any per-purpose check; short-circuit in both
  -- fail-fast and exhaustive modes before walking the purpose lists.
  if self:_check_vendor_gate(parser, vendor_id, failures) then
    return false, failures
  end

  -- 5. Consent purposes.
  self:_check_consent_purposes(
    parser,
    vendor_id,
    conf.strict_legal_basis,
    failures,
    stop_on_first,
    conf.consent_purpose_ids,
    flexible_set
  )
  if stop_on_first and #failures > 0 then
    return false, failures
  end

  -- 6. Legitimate-interest purposes.
  self:_check_li_purposes(
    parser,
    vendor_id,
    conf.strict_legal_basis,
    failures,
    stop_on_first,
    conf.legitimate_interest_purpose_ids,
    flexible_set
  )

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
