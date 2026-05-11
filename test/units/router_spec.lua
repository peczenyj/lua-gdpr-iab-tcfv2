local tcf = require("gdpr.iab.tcfv2")

describe("Multi-Segment Router", function()
  -- This string has Core + Publisher TC (Segment Type 3)
  local tc_string = "CP188cAQKFpAAAHABBENBSFsAP_gAEPgAAiQKqNX_H__bW9r8X73aft0eY1P9_j77uQxBhfJE-4"
    .. "FzLvW_JwXx2ExNA36tqIKmRIEu3bBIQNlHJHUTVigaogVryHMak2cpTNKJ6BkiFMRM2dYCF5vm4tj-QKY5_r993dx2D"
    .. "-t_dv83dzyz81Hn3f5_2e0eLCdQ5-tDfv9bROb-9IPd_78v4v8_l_rk2_eT1n_tevr7D_-ft8__XW_9_fff_9Pn_-uB"
    .. "-_3_vf_EFUwCTDQqIA-wJCQg0DCKBACoKwgIoFAQAAJA0QEAJgwKdgYALrCRACAFAAMEAIAAQZAAgAAAgAQiACQAoEA"
    .. "AEAgUAAYAEAwEABAwAAgAsBAIAAQHQMUwIIFAsIEjMioUwIQoEggJbKhBICgQVwhCLPAIgERMFAAgAAAVgACAsFgcSS"
    .. "AlQkECXUG0AABAAgFEIFQgk9MAAwJmy1B4MG0ZWmAYPmCRDTAMgCIIyEAAAA.f_wACHwAAAAA"

  it("routes to Publisher TC segment correctly", function()
    local parser, err = tcf.new(tc_string)
    assert.is_nil(err)
    assert.is_not_nil(parser.pubPurposesConsent)
    assert.is_true(
      parser.pubPurposesConsent[1],
      "pubPurposesConsent[1] should be true"
    )
    assert.is_true(
      parser.pubPurposesConsent[10],
      "pubPurposesConsent[10] should be true"
    )
  end)

  it("exposes custom purposes if present", function()
    local parser = tcf.new(tc_string)
    assert.are.equal(0, parser.numCustomPurposes)
  end)

  it(
    "appends a warning when a non-core segment has invalid base64 (lenient)",
    function()
      -- "@" is outside the base64url alphabet, so the trailing segment will
      -- fail base64 decoding. Lenient mode (default) should not error;
      -- instead it appends the failure to parser.warnings via core.warnings.
      local parser = tcf.new(tc_string .. ".@@@@@@@@")
      assert.is_not_nil(parser)
      assert.is_true(
        #parser.warnings > 0,
        "expected a warning for the malformed trailing segment"
      )
      local found = false
      for _, w in ipairs(parser.warnings) do
        if w:match("invalid base64 in segment") then
          found = true
          break
        end
      end
      assert.is_true(found, "warning should reference invalid base64 segment")
    end
  )

  it(
    "fails in strict mode when a non-core segment has invalid base64",
    function()
      local parser, err = tcf.new(tc_string .. ".@@@@@@@@", { strict = true })
      assert.is_nil(parser)
      assert.match("invalid base64 in segment", err)
    end
  )
end)
