local harness = require("test.reference.golden_harness")
local Validator = require("gdpr.iab.tcfv2.validator")

describe("Validator Reference Parity (Phase 5 Exhaustive)", function()
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
    local continue_on_failure = os.getenv("TCF_CONTINUE_ON_FAILURE") == "1"
    local failures = {}

    harness.read_golden(function(data)
      count = count + 1

      if verbose then
        print(
          string.format("  -> Validating line %d: %s", count, data.tc_string)
        )
      elseif count % 1000 == 0 then
        io.write(".")
        io.flush()
      end

      if data.expect_failure then
        return
      end

      for name, v in pairs(SCENARIOS) do
        local expected = data.tests.validator[name].valid
        local actual, err = v:validate(data.tc_string)

        if actual ~= expected then
          local msg = string.format(
            "Line %d: Scenario '%s' mismatch. Expected %s, got %s (Err: %s) [String: %s]",
            count,
            name,
            tostring(expected),
            tostring(actual),
            tostring(err),
            data.tc_string
          )
          if continue_on_failure then
            table.insert(failures, msg)
          else
            error(msg)
          end
        end
      end

      if count >= limit then
        return true
      end
    end)

    if count % 1000 ~= 0 and not verbose then
      print("")
    end

    if #failures > 0 then
      error(
        string.format(
          "Verification failed with %d mismatches:\n%s",
          #failures,
          table.concat(failures, "\n")
        )
      )
    end
  end)
end)
