local tcf = require("gdpr.iab.tcfv2")
local harness = require("test.reference.golden_harness")

describe("Fuzz Testing", function()
  describe("Golden Corpus Random Sampling", function()
    it("matches Perl logical output for random vendors", function()
      local count = 0
      local limit = os.getenv("TCF_QUICK") == "1" and 128 or 999999
      harness.read_golden(function(data)
        count = count + 1

        if data.expect_failure then
          return
        end

        -- Dynamically detect if this line has fuzz data
        if not data.tests.fuzz then
          return
        end

        local parser = assert(tcf.new(data.tc_string))
        local expected = data.tests.fuzz

        -- verify 10 random IDs between 1 and 2000
        for _ = 1, 10 do
          local vid = math.random(1, 2000)
          local actual_val = parser.vendorConsents[vid] == true
          local expected_val = (expected.consents[tostring(vid)] == true)
          assert.are.equal(
            expected_val,
            actual_val,
            string.format("Line %d: Vendor %d mismatch", count, vid)
          )
        end

        if count >= limit then
          return true
        end
      end)
    end)
  end)

  describe("Random Bitstream Robustness", function()
    it("does not crash on random data", function()
      -- Deterministic seed so this test is reproducible across CI runs.
      -- Override with TCF_FUZZ_SEED for ad-hoc exploration.
      math.randomseed(tonumber(os.getenv("TCF_FUZZ_SEED")) or 42)
      local chars =
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
      for _ = 1, 100 do
        local len = math.random(10, 200)
        local res = {}
        for i = 1, len do
          local r = math.random(1, #chars)
          res[i] = chars:sub(r, r)
        end
        local tc = table.concat(res)

        -- We just ensure it returns nil, err instead of throwing a Lua error
        local status, _, _ = pcall(tcf.new, tc)
        assert.is_true(status, "Parser crashed on random input: " .. tc)
      end
    end)
  end)
end)
