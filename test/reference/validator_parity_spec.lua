local harness = require("test.reference.golden_harness")
local Validator = require("gdpr.iab.tcfv2.validator")

describe("Validator Reference Parity", function()
  local SCENARIOS = {
    v284_baseline = Validator.new({ vendor_id = 284 }),
    v284_consent_p1 = Validator.new({
      vendor_id = 284,
      consent_purpose_ids = { 1 },
    }),
    v99999_consent_p1 = Validator.new({
      vendor_id = 99999,
      consent_purpose_ids = { 1 },
    }),
    v284_li_p7 = Validator.new({
      vendor_id = 284,
      legitimate_interest_purpose_ids = { 7 },
    }),
    v284_flex_p2_consent = Validator.new({
      vendor_id = 284,
      consent_purpose_ids = { 2 },
      flexible_purpose_ids = { 2 },
    }),
    v284_flex_p7_li = Validator.new({
      vendor_id = 284,
      legitimate_interest_purpose_ids = { 7 },
      flexible_purpose_ids = { 7 },
    }),
    v284_min_policy_v5 = Validator.new({
      vendor_id = 284,
      min_tcf_policy_version = 5,
    }),
    v284_verify_disclosed = Validator.new({
      vendor_id = 284,
      verify_disclosed_vendors = true,
    }),
  }

  it("matches all validation scenarios from the Golden Corpus", function()
    local count = 0
    local limit = os.getenv("TCF_QUICK") == "1" and 128 or 999999
    local verbose = os.getenv("TCF_VERBOSE") == "1"

    harness.read_golden(function(data)
      count = count + 1

      if verbose then
        print(string.format("  -> Validating line %d", count))
      end

      if data.expect_failure then
        return
      end

      for name, v in pairs(SCENARIOS) do
        local expected = data.tests.validator[name].valid
        local actual, err = v:validate(data.tc_string)

        assert.are.equal(
          expected,
          actual,
          string.format(
            "Line %d: Scenario '%s' mismatch. Expected %s, got %s (Err: %s)",
            count,
            name,
            tostring(expected),
            tostring(actual),
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
