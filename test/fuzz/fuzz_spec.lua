local tcf = require("gdpr.iab.tcfv2")

describe("Fuzz Testing", function()
  describe("Random Bitstream Robustness", function()
    it("does not crash on random data", function()
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
