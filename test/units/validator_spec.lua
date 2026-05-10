local Validator = require("gdpr.iab.tcfv2.validator")

describe("Validator", function()
  local tc_string = "CP188cAQKFpAAAHABBENBSFsAP_gAEPgAAiQKqNX_H__bW9r8X73aft0eY1P9_j77uQxBhfJE-4"
    .. "FzLvW_JwXx2ExNA36tqIKmRIEu3bBIQNlHJHUTVigaogVryHMak2cpTNKJ6BkiFMRM2dYCF5vm4tj-QKY5_r993dx2D"
    .. "-t_dv83dzyz81Hn3f5_2e0eLCdQ5-tDfv9bROb-9IPd_78v4v8_l_rk2_eT1n_tevr7D_-ft8__XW_9_fff_9Pn_-uB"
    .. "-_3_vf_EFUwCTDQqIA-wJCQg0DCKBACoKwgIoFAQAAJA0QEAJgwKdgYALrCRACAFAAMEAIAAQZAAgAAAgAQiACQAoEA"
    .. "AEAgUAAYAEAwEABAwAAgAsBAIAAQHQMUwIIFAsIEjMioUwIQoEggJbKhBICgQVwhCLPAIgERMFAAgAAAVgACAsFgcSS"
    .. "AlQkECXUG0AABAAgFEIFQgk9MAAwJmy1B4MG0ZWmAYPmCRDTAMgCIIyEAAAA.f_wACHwAAAAA"

  it("validates vendor consent correctly", function()
    local v = Validator.new({
      vendor_id = 284,
      consent_purpose_ids = { 1 },
    })
    local ok, err = v:validate(tc_string)
    assert.is_true(ok)
    assert.is_nil(err)
  end)

  it("fails when vendor has no consent", function()
    local v = Validator.new({
      vendor_id = 3, -- Vendor 3 has no consent in this string
      consent_purpose_ids = { 1 },
    })
    local ok, err = v:validate(tc_string)
    assert.is_false(ok)
    assert.are.equal("missing consent for vendor 3", err)
  end)

  it("fails when purpose has no consent", function()
    local v = Validator.new({
      vendor_id = 284,
      consent_purpose_ids = { 24 }, -- Purpose 24 has no consent
    })
    local ok, err = v:validate(tc_string)
    assert.is_false(ok)
    assert.are.equal("missing consent for purpose 24", err)
  end)

  it("respects runtime overrides", function()
    local v = Validator.new({
      vendor_id = 284,
    })
    -- Override vendor_id to one that doesn't have consent
    local ok, err =
      v:validate(tc_string, { vendor_id = 3, consent_purpose_ids = { 1 } })
    assert.is_false(ok)
    assert.are.equal("missing consent for vendor 3", err)
  end)

  it("validates legitimate interest", function()
    local v = Validator.new({
      vendor_id = 284,
      legitimate_interest_purpose_ids = { 2 },
    })
    local ok = v:validate(tc_string)
    assert.is_true(ok)
  end)

  it("fails legitimate interest for purpose 1", function()
    local v = Validator.new({
      vendor_id = 284,
      legitimate_interest_purpose_ids = { 1 },
    })
    local ok, err = v:validate(tc_string)
    assert.is_false(ok)
    assert.are.equal("purpose 1 does not allow legitimate interest", err)
  end)

  it("enforces min_tcf_policy_version", function()
    local v = Validator.new({
      vendor_id = 284,
      min_tcf_policy_version = 10,
    })
    local ok, err = v:validate(tc_string)
    assert.is_false(ok)
    assert.match("policy version %d+ is less than required 10", err)
  end)
end)
