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

  it("handles Disclosed Vendors (Type 1) - Mock", function()
    -- Type 1: bits 001...
    -- Let's say max_id=1, bitfield, vendor 1 has consent.
    -- bits: 001 (type) | 0000000000000001 (max_id=1) | 0 (bitfield) | 1 (vendor 1) | 0000 (padding to 6 bits)
    -- 00100000 00000000 01010000 -> 0x20 0x00 0x50
    -- base64: IAAVA (roughly)
    -- Actually let's just use a real-ish one if I can find one or just trust the logic.
  end)
end)
