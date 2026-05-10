local tcf = require("gdpr.iab.tcfv2")

describe("Core Segment", function()
  local tc_string = "CP188cAQKFpAAAHABBENBSFsAP_gAEPgAAiQKqNX_H__bW9r8X73aft0eY1P9_j77uQxBhfJE-4"
    .. "FzLvW_JwXx2ExNA36tqIKmRIEu3bBIQNlHJHUTVigaogVryHMak2cpTNKJ6BkiFMRM2dYCF5vm4tj-QKY5_r993dx2D"
    .. "-t_dv83dzyz81Hn3f5_2e0eLCdQ5-tDfv9bROb-9IPd_78v4v8_l_rk2_eT1n_tevr7D_-ft8__XW_9_fff_9Pn_-uB"
    .. "-_3_vf_EFUwCTDQqIA-wJCQg0DCKBACoKwgIoFAQAAJA0QEAJgwKdgYALrCRACAFAAMEAIAAQZAAgAAAgAQiACQAoEA"
    .. "AEAgUAAYAEAwEABAwAAgAsBAIAAQHQMUwIIFAsIEjMioUwIQoEggJbKhBICgQVwhCLPAIgERMFAAgAAAVgACAsFgcSS"
    .. "AlQkECXUG0AABAAgFEIFQgk9MAAwJmy1B4MG0ZWmAYPmCRDTAMgCIIyEAAAA.f_wACHwAAAAA"

  it("parses fixed header fields correctly", function()
    local parser, err = tcf.new(tc_string)
    assert.is_nil(err)
    assert.are.equal(2, parser.version)
    assert.are.equal(7, parser.cmpId)
    assert.are.equal(1, parser.cmpVersion)
    assert.are.equal(1, parser.consentScreen)
    assert.are.equal("EN", parser.consentLanguage)
    assert.are.equal(82, parser.vendorListVersion)
    assert.are.equal(5, parser.policyVersion)
    assert.is_true(parser.isServiceSpecific)
    assert.is_false(parser.useNonStandardStacks)
    assert.is_false(parser.purposeOneTreatment)
    assert.are.equal("ES", parser.publisherCountryCode)
  end)

  it("parses dates correctly", function()
    local parser = tcf.new(tc_string)
    -- deciseconds: 1701129600 * 10 = 17011296000
    assert.are.equal(17011296000, parser.created)
  end)

  it("parses purpose bitfields correctly", function()
    local parser = tcf.new(tc_string)
    assert.is_true(parser.purposeConsents[1])
    assert.is_true(parser.purposeConsents[10])
    assert.is_true(parser.purposeLegitimateInterests[10])
    assert.is_false(parser.purposeLegitimateInterests[1]) -- Purpose 1 never allows LI
  end)

  it("parses vendor consents (Range encoding)", function()
    local parser = tcf.new(tc_string)
    assert.is_true(parser.vendorConsents[284], "vendor 284 should have consent")
    assert.is_true(parser.vendorConsents[1], "vendor 1 should have consent")
  end)

  it("handles targetVendors optimization", function()
    local parser = tcf.new(tc_string, { targetVendors = { 284, 999 } })
    assert.is_true(parser.vendorConsents[284])
    assert.is_nil(parser.vendorConsents[1], "vendor 1 should be ignored due to targetVendors")
  end)
end)
