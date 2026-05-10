local harness = require("test.reference.golden_harness")
local Validator = require("gdpr.iab.tcfv2.validator")

describe("Validator Reference Parity", function()
  it("matches 'vendor_284_purpose_1_allowed' from Golden Corpus", function()
    -- Create a validator for the specific sampling check in the corpus
    local v = Validator.new({
      vendor_id = 284,
      consent_purpose_ids = { 1 },
    })

    local count = 0
    local limit = os.getenv("TCF_QUICK") == "1" and 128 or 999999

    harness.read_golden(function(data)
      count = count + 1

      if data.expect_failure then
        return
      end

      -- The corpus gives us the answer for "is vendor 284 allowed for purpose 1"
      local expected = data.tests.sampling.vendor_284_purpose_1_allowed

      -- Run our validator
      local actual, err = v:validate(data.tc_string)

      -- Note: v:validate returns (false, "err") if denied.
      -- We compare the boolean result.
      assert.are.equal(
        expected,
        actual,
        string.format(
          "Line %d: Validator mismatch for string %s. Expected %s, got %s (Err: %s)",
          count,
          data.tc_string,
          tostring(expected),
          tostring(actual),
          tostring(err)
        )
      )

      if count >= limit then
        return true
      end
    end)
  end)
end)
