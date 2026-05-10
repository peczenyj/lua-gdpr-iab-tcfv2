local harness = require("golden_harness")
local parity = require("parity_helper")
local tcf = require("gdpr.iab.tcfv2")

-- Environment configuration
local FULL_CORPUS = os.getenv("TCF_FULL_CORPUS") ~= "0"
local VERBOSE = os.getenv("TCF_VERBOSE") == "1"
local CONTINUE_ON_FAILURE = os.getenv("TCF_CONTINUE_ON_FAILURE") == "1"
local QUICK_MODE = os.getenv("TCF_QUICK") == "1"
local FUZZ_MODE = os.getenv("TCF_FUZZ") == "1"

if QUICK_MODE then
  FULL_CORPUS = false
end

-- Robust Limit Handling
local function get_limit(env_var, default)
  local val = tonumber(os.getenv(env_var))
  if not val or val < 0 then
    return default
  end
  return val
end

local DEEP_LIMIT = get_limit("TCF_DEEP_LIMIT", 16)
local SCAN_LIMIT = get_limit("TCF_SCAN_LIMIT", 128)

-- Ensure logic remains sound
if DEEP_LIMIT > SCAN_LIMIT and not FULL_CORPUS then
  SCAN_LIMIT = DEEP_LIMIT
end

describe("Golden Parity", function()
  it("matches Perl logical output", function()
    local count = 0
    local failures = {}
    local filename = harness.get_golden_path()

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

      -- Wrap the actual test logic in a pcall to handle continue-on-failure
      local status, err = pcall(function()
        local parser, p_err = tcf.new(data.tc_string)
        if not parser then
          error(string.format("Failed to parse: %s", tostring(p_err)))
        end

        -- 1. Full Deep Comparison for requested items
        if count <= DEEP_LIMIT or FULL_CORPUS then
          local actual = parity.map_to_perl_shape(parser)
          local expected = data.tests.to_json
          local ok, diff_err = parity.deep_compare(actual, expected)

          if not ok then
            error(tostring(diff_err))
          end
        end

        -- 2. Header and Fuzz sampling for other items (Quick mode or Non-Deep)
        if not FULL_CORPUS and count > DEEP_LIMIT then
          local expected = data.tests.to_json

          -- Verify Header Parity (Deterministic, always run)
          assert.are.equal(expected.version, parser.version)
          assert.are.equal(expected.cmp_id, parser.cmpId)
          assert.are.equal(expected.policy_version, parser.policyVersion)

          -- 3. Randomized Fuzz/Sampling (Only enabled via TCF_FUZZ=1)
          if FUZZ_MODE then
            for _ = 1, 5 do
              local vid = math.random(1, 2000)
              local actual_val = parser.vendorConsents[vid] == true
              local expected_val = (
                expected.vendor.consents[tostring(vid)] == true
              )
              assert.are.equal(
                expected_val,
                actual_val,
                string.format("Vendor %d mismatch", vid)
              )
            end
          end
        end
      end)

      if not status then
        local failure_msg =
          string.format("[%s:%d] %s", filename, count, tostring(err))
        if CONTINUE_ON_FAILURE then
          table.insert(failures, failure_msg)
          if VERBOSE then
            print("     !! FAILURE: " .. failure_msg)
          end
        else
          error(failure_msg)
        end
      end

      -- Stop reading file if we are in QUICK mode and hit the limit
      if not FULL_CORPUS and count >= SCAN_LIMIT then
        return true
      end
    end)

    if #failures > 0 then
      local error_blob = table.concat(failures, "\n")
      error(
        "Corpus Parity Failed with " .. #failures .. " errors:\n" .. error_blob
      )
    end
  end)
end)
