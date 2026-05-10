local harness = require("golden_harness")
local parity = require("parity_helper")
local tcf = require("gdpr.iab.tcfv2")

-- Environment configuration
local FULL_CORPUS = os.getenv("TCF_FULL_CORPUS") == "1"
local VERBOSE = os.getenv("TCF_VERBOSE") == "1"

-- Robust Limit Handling
local function get_limit(env_var, default)
  local val = tonumber(os.getenv(env_var))
  if not val or val < 0 then
    return default
  end
  return val
end

local DEEP_LIMIT = get_limit("TCF_DEEP_LIMIT", 16)
local SCAN_LIMIT = get_limit("TCF_SCAN_LIMIT", 100)

-- Ensure logic remains sound if user provides small scan limit but large deep limit
if DEEP_LIMIT > SCAN_LIMIT and not FULL_CORPUS then
  SCAN_LIMIT = DEEP_LIMIT
end

describe("Golden Parity", function()
  it("matches Perl logical output", function()
    local count = 0
    harness.read_golden(function(data)
      count = count + 1

      if VERBOSE then
        print(
          string.format(
            "  -> Processing line %d (%s...)",
            count,
            data.tc_string:sub(1, 20)
          )
        )
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

      -- 1. Full Deep Comparison for the first X items
      if count <= DEEP_LIMIT or FULL_CORPUS then
        local actual = parity.map_to_perl_shape(parser:to_table())
        local expected = data.tests.to_json
        local ok, diff_err = parity.deep_compare(actual, expected)
        assert.is_true(
          ok,
          string.format("Deep mismatch at line %d: %s", count, tostring(diff_err))
        )
      end

      -- 2. Randomized Fuzz/Sampling for other items (if not doing full corpus)
      if count > DEEP_LIMIT and not FULL_CORPUS then
        local expected = data.tests.to_json

        -- Verify Header Parity (Cheap)
        assert.are.equal(expected.version, parser.version)
        assert.are.equal(expected.cmp_id, parser.cmpId)
        assert.are.equal(expected.policy_version, parser.policyVersion)

        -- verify a random subset of vendor consents
        for _ = 1, 5 do
          local vid = math.random(1, 2000)
          local actual_val = parser.vendorConsents[vid] == true
          local expected_val = (expected.vendor.consents[tostring(vid)] == true)
          assert.are.equal(
            expected_val,
            actual_val,
            string.format("Fuzz mismatch: Vendor %d at line %d", vid, count)
          )
        end
      end

      -- 3. Global scan limit for dev speed
      if not FULL_CORPUS and count >= SCAN_LIMIT then
        return true -- Stop reading file
      end
    end)
  end)
end)
