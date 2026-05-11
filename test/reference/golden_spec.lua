local harness = require("test.reference.golden_harness")
local parity = require("test.reference.parity_helper")
local tcf = require("gdpr.iab.tcfv2")

describe("Golden Corpus Integrity", function()
  it("verifies the MD5 checksum of the golden file", function()
    local path = harness.get_golden_path()
    local f = io.popen("md5sum " .. path)
    local result = f:read("*a")
    f:close()

    local md5 = result:match("^(%x+)")
    assert.are.equal(
      "237b6a670d9a52625dc28a1126c6c90a",
      md5,
      "Golden corpus file is corrupted or modified"
    )
  end)
end)

describe("Golden Parity", function()
  it("parses real-world TCF strings without crashing", function()
    local count = 0
    local limit = os.getenv("TCF_QUICK") == "1" and 128 or 999999
    local verbose = os.getenv("TCF_VERBOSE") == "1"

    harness.read_golden(function(data)
      count = count + 1

      if verbose then
        print(string.format("  -> Parsing line %d", count))
      end

      if data.expect_failure then
        return
      end

      local parser, err = tcf.new(data.tc_string)
      if not parser then
        error(
          string.format(
            "Line %d: Failed to parse %s: %s",
            count,
            data.tc_string,
            tostring(err)
          )
        )
      end

      if count >= limit then
        return true
      end
    end)
  end)
end)

-- Field-level structural parity.
--
-- For the corpus's rich tier (the first 128 rows still carry
-- tests.to_json, the rest are stripped by scripts/optimize_golden.sh)
-- we deep-compare a subset of the Lua parser output against Perl's
-- serialized form. The subset is intentional: only fields whose Lua and
-- Perl representations are directly comparable land here. Fields with
-- known representational differences are explicitly deferred and
-- documented inline:
--
--   created / last_updated -- Lua emits deciseconds-since-epoch integers
--     to match the wire format; Perl serializes ISO 8601 strings.
--   publisher.* (consents, custom_purposes, legitimate_interests,
--     restrictions) -- Lua's publisher TC fields are flat siblings
--     (pubPurposesConsent, customPurposesConsent, publisherRestrictions);
--     Perl nests them under a publisher object with different keys.
--   tc_string -- always matches by construction; no signal value.
--
-- The bool-map subset (purpose, vendor, special_features_opt_in) needs
-- one transformation before comparison: Perl's to_json omits false
-- entries from its bitfields, while Lua preserves them. strip_false()
-- normalizes the Lua side to match.
describe("Golden Field-Level Parity (rich tier)", function()
  -- Strip false-valued keys from a bool-map so a fixed-length Lua bitfield
  -- compares cleanly against Perl's sparse JSON representation.
  local function strip_false(t)
    if type(t) ~= "table" then
      return t
    end
    local r = {}
    for k, v in pairs(t) do
      if v then
        r[k] = v
      end
    end
    return r
  end

  -- Project parser:to_table() into Perl's snake_case + nested shape so
  -- parity_helper.deep_compare can compare the two head-to-head.
  local function project_lua(parser)
    local t = parser:to_table()
    return {
      cmp_id = t.cmpId,
      cmp_version = t.cmpVersion,
      consent_screen = t.consentScreen,
      consent_language = t.consentLanguage,
      is_service_specific = t.isServiceSpecific,
      policy_version = t.policyVersion,
      publisher_country_code = t.publisherCountryCode,
      purpose_one_treatment = t.purposeOneTreatment,
      use_non_standard_stacks = t.useNonStandardStacks,
      vendor_list_version = t.vendorListVersion,
      version = t.version,
      purpose = {
        consents = strip_false(t.purposeConsents),
        legitimate_interests = strip_false(t.purposeLegitimateInterests),
      },
      vendor = {
        consents = strip_false(t.vendorConsents),
        legitimate_interests = strip_false(t.vendorLegitimateInterests),
      },
      special_features_opt_in = strip_false(t.specialFeaturesOptIn),
    }
  end

  -- Pick the matching subset of Perl's to_json to compare against.
  local function project_expected(tj)
    return {
      cmp_id = tj.cmp_id,
      cmp_version = tj.cmp_version,
      consent_screen = tj.consent_screen,
      consent_language = tj.consent_language,
      is_service_specific = tj.is_service_specific,
      policy_version = tj.policy_version,
      publisher_country_code = tj.publisher_country_code,
      purpose_one_treatment = tj.purpose_one_treatment,
      use_non_standard_stacks = tj.use_non_standard_stacks,
      vendor_list_version = tj.vendor_list_version,
      version = tj.version,
      purpose = tj.purpose,
      vendor = tj.vendor,
      special_features_opt_in = tj.special_features_opt_in,
    }
  end

  it("matches Perl's to_json across the rich-tier subset", function()
    -- Default 16 rows so a normal CI run touches a meaningful sample
    -- without paying for all 128. Override with TCF_DEEP_LIMIT for full
    -- coverage when investigating a regression.
    local limit = tonumber(os.getenv("TCF_DEEP_LIMIT")) or 16
    local verbose = os.getenv("TCF_VERBOSE") == "1"
    local count = 0
    local rich_count = 0
    local failures = {}

    harness.read_golden(function(data)
      count = count + 1
      if data.expect_failure or not data.tests or not data.tests.to_json then
        return
      end

      rich_count = rich_count + 1
      if verbose then
        print(string.format("  -> Deep-comparing line %d", count))
      end

      local parser = assert(
        tcf.new(data.tc_string),
        string.format("Line %d: parser construction failed", count)
      )
      local actual = project_lua(parser)
      local expected = project_expected(data.tests.to_json)

      local ok, err = parity.deep_compare(actual, expected)
      if not ok then
        table.insert(
          failures,
          string.format("Line %d: %s", count, tostring(err))
        )
      end

      if rich_count >= limit then
        return true
      end
    end)

    if #failures > 0 then
      error(
        string.format(
          "Field-level parity mismatches (%d):\n%s",
          #failures,
          table.concat(failures, "\n")
        )
      )
    end
  end)
end)
