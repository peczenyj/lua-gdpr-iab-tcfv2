local harness = require("test.reference.golden_harness")
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
