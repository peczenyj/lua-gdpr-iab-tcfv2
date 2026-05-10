local harness = require("test.golden_harness")

describe("Golden Harness", function()
  it("can read the first entry of the golden file", function()
    local count = 0
    harness.read_golden(function(data)
      count = count + 1
      if count == 1 then
        assert.is_not.nil(data.tc_string)
        assert.is_not.nil(data.tests)
      end
    end)
    assert.is_true(count > 0)
  end)
end)
