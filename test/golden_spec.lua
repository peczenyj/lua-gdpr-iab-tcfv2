local harness = require("test.golden_harness")
local parity = require("test.parity_helper")
local tcf = require("gdpr.iab.tcfv2")

describe("Golden Parity", function()
  it("matches Perl logical output for the core segment", function()
    local count = 0
    harness.read_golden(function(data)
      count = count + 1
      if data.expect_failure then return end
      
      local parser, err = tcf.new(data.tc_string)
      if not parser then
        error("Failed to parse " .. data.tc_string .. ": " .. tostring(err))
      end
      
      local actual = parity.map_to_perl_shape(parser:to_table())
      local expected = data.tests.to_json
      
      -- Compare basic fields
      local fields = {
        "version", "cmp_id", "cmp_version", "consent_screen", "consent_language",
        "vendor_list_version", "policy_version", "is_service_specific",
        "use_non_standard_stacks", "purpose_one_treatment", "publisher_country_code"
      }
      
      for _, f in ipairs(fields) do
        assert.are.equal(expected[f], actual[f], "Field mismatch: " .. f .. " in " .. data.tc_string)
      end
      
      -- Compare dates (ignore minor formatting differences if they exist)
      assert.are.equal(expected.created, actual.created, "Created date mismatch")
      assert.are.equal(expected.last_updated, actual.last_updated, "Last updated date mismatch")

      -- Sampling tests
      if data.tests.sampling then
        local sampling = data.tests.sampling
        if sampling.vendor_284_consent ~= nil then
          assert.are.equal(sampling.vendor_284_consent, parser.vendorConsents[284] == true, "Sampling mismatch: vendor_284_consent")
        end
        if sampling.purpose_1_consent ~= nil then
          assert.are.equal(sampling.purpose_1_consent, parser.purposeConsents[1] == true, "Sampling mismatch: purpose_1_consent")
        end
      end

      -- Only test first 50 entries for now to keep CI fast during dev
      if count >= 50 then return true end
    end)
  end)
end)
