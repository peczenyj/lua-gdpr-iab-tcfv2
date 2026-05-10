local harness = require("test.reference.golden_harness")
local parity = require("test.reference.parity_helper")
local tcf = require("gdpr.iab.tcfv2")

-- Environment configuration
local FULL_CORPUS = os.getenv("TCF_FULL_CORPUS") == "1"
local VERBOSE = os.getenv("TCF_VERBOSE") == "1"
local CONTINUE_ON_FAILURE = os.getenv("TCF_CONTINUE_ON_FAILURE") == "1"
local QUICK_MODE = os.getenv("TCF_QUICK") == "1"

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

if FULL_CORPUS then
  SCAN_LIMIT = 999999
elseif QUICK_MODE then
  SCAN_LIMIT = 128
end

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

        local actual = parity.map_to_perl_shape(parser)
        local expected = data.tests.to_json
        local ok, diff_err = parity.deep_compare(actual, expected)

        if not ok then
          error(tostring(diff_err))
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

      if count >= SCAN_LIMIT then
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
