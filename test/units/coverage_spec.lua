local tcf = require("gdpr.iab.tcfv2")
local Validator = tcf.Validator

describe("Validator Error Paths and Edge Cases", function()
  -- TC string with 284 consent
  local base_string = "CP188cAQKFpAAAHABBENBSFsAP_gAEPgAAiQKqNX_H__bW9r8X73aft0eY1P9_j77uQxBhfJE-4"
    .. "FzLvW_JwXx2ExNA36tqIKmRIEu3bBIQNlHJHUTVigaogVryHMak2cpTNKJ6BkiFMRM2dYCF5vm4tj-QKY5_r993dx2D"
    .. "-t_dv83dzyz81Hn3f5_2e0eLCdQ5-tDfv9bROb-9IPd_78v4v8_l_rk2_eT1n_tevr7D_-ft8__XW_9_fff_9Pn_-uB"
    .. "-_3_vf_EFUwCTDQqIA-wJCQg0DCKBACoKwgIoFAQAAJA0QEAJgwKdgYALrCRACAFAAMEAIAAQZAAgAAAgAQiACQAoEA"
    .. "AEAgUAAYAEAwEABAwAAgAsBAIAAQHQMUwIIFAsIEjMioUwIQoEggJbKhBICgQVwhCLPAIgERMFAAgAAAVgACAsFgcSS"
    .. "AlQkECUG0AABAAgFEIFQgk9MAAwJmy1B4MG0ZWmAYPmCRDTAMgCIIyEAAAA.f_wACHwAAAAA"

  it("handles table input in get_parser", function()
    local parser = tcf.new(base_string)
    local v = Validator.new({ vendor_id = 284 })
    local ok, err = v:validate(parser)
    assert.is_true(ok, err)
  end)

  it("fails when vendor_id is missing", function()
    local v = Validator.new({})
    local ok, err = v:validate(base_string)
    assert.is_false(ok)
    assert.are.equal("missing vendor_id", err)
  end)

  it("non-flexible purpose follows the standard consent path", function()
    -- Previously this test wired flexible_purpose_ids = { 2 } with
    -- consent_purpose_ids = { 1 } -- a coherence violation after Phase 4
    -- (orphan flexibles now raise in the constructor). The intent here is
    -- just to verify the happy-path consent flow when no flex flag applies.
    local v = Validator.new({
      vendor_id = 284,
      consent_purpose_ids = { 1 },
    })
    local ok, err = v:validate(base_string)
    assert.is_true(ok, err)
  end)

  it("validates all errors in validate_all", function()
    local v = Validator.new({
      vendor_id = 999, -- No consent
      consent_purpose_ids = { 24 }, -- No consent
    })
    local ok, errs = v:validate_all(base_string)
    assert.is_false(ok)
    assert.are.equal("table", type(errs))
    assert.is_true(#errs > 0)
  end)

  describe("Publisher Restrictions Edge Cases", function()
    it("fails when purpose is restricted to Not Allowed (Type 0)", function()
      local parser = tcf.new(base_string)
      -- Type 0: Not Allowed
      parser.publisherRestrictions[1] = { [284] = 0 }

      local v = Validator.new({ vendor_id = 284, consent_purpose_ids = { 1 } })
      local ok, err = v:validate(parser)
      assert.is_false(ok)
      assert.are.equal(
        "publisher restriction: purpose 1 not allowed (vendor 284)",
        err
      )
    end)

    it(
      "fails when LI is requested but restriction is Require Consent (Type 1)",
      function()
        local parser = tcf.new(base_string)
        -- Force LI and Vendor LI to true for test
        parser.purposeLegitimateInterests[2] = true
        parser.vendorLegitimateInterests[284] = true
        -- Type 1: Require Consent
        parser.publisherRestrictions[2] = { [284] = 1 }

        local v = Validator.new({
          vendor_id = 284,
          legitimate_interest_purpose_ids = { 2 },
        })
        local ok, err = v:validate(parser)
        assert.is_false(ok)
        assert.are.equal(
          "publisher restriction: purpose 2 requires consent (vendor 284)",
          err
        )
      end
    )

    it("handles Type 2 restriction in consent check", function()
      local parser = tcf.new(base_string)
      -- Type 2: Require LI
      parser.publisherRestrictions[1] = { [284] = 2 }

      local v = Validator.new({ vendor_id = 284, consent_purpose_ids = { 1 } })
      local ok, err = v:validate(parser)
      assert.is_false(ok)
      assert.are.equal(
        "publisher restriction: purpose 1 requires legitimate interest (vendor 284)",
        err
      )
    end)
  end)
end)

describe("Allowed Vendors (Type 2 Segment)", function()
  local AllowedVendors = require("gdpr.iab.tcfv2.allowed_vendors")
  local base64 = require("gdpr.iab.tcfv2.base64")

  it("decodes Allowed Vendors segment correctly (Bitfield)", function()
    local s = "QLvNR_G__bXlv-bb36ftkeYxf9_hr7sQxBgbJs24FzLvW_JwX32E7NEzatqYKmRIEu3bBI"
      .. "QNtHJjURVChKIgVrzDsaEyUoTtKJ-BkiHMRY2NYCFxvm4tjWQCZ5vr_91d9mT-N7dr-2dzyy7"
      .. "hnv3a9_-S1WJidKYetHfv8ZBKT-_IU9_x-_4v4_N7pE2-eS1v_tGvt639-4vP_dpvxt-7yffz"
      .. "____73_e7X__d_______Xf_7_____________cAA"
    local data = base64.decode_url(s)
    local obj = AllowedVendors.new(data)
    assert.is_not_nil(obj)
    assert.is_true(obj.vendorAllowed[284])

    local tbl = obj:to_table()
    assert.is_true(tbl.vendorAllowed[284])
  end)

  it("decodes Allowed Vendors segment correctly (Range)", function()
    local s = "QKhwLIAFAAWAA0ACoAFwAOAAgABaADIAGgARQAmABQAC2AGEANoAgIBBgEIAI4AVoA5AB3AD"
      .. "xAH6AScApoBnADTgG8AToAn8BTYC4QF5gMZAbmA44ByYEJAIzASNAkyBSUClYFQw"
    local data = base64.decode_url(s)
    local obj = AllowedVendors.new(data)
    assert.is_not_nil(obj)
    assert.is_true(obj.vendorAllowed[1317])

    local tbl = obj:to_table()
    assert.is_true(tbl.vendorAllowed[1317])
  end)

  it("supports targetVendors optimization in Allowed Vendors", function()
    local s = "QLvNR_G__bXlv-bb36ftkeYxf9_hr7sQxBgbJs24FzLvW_JwX32E7NEzatqYKmRIEu3bBI"
      .. "QNtHJjURVChKIgVrzDsaEyUoTtKJ-BkiHMRY2NYCFxvm4tjWQCZ5vr_91d9mT-N7dr-2dzyy7"
      .. "hnv3a9_-S1WJidKYetHfv8ZBKT-_IU9_x-_4v4_N7pE2-eS1v_tGvt639-4vP_dpvxt-7yffz"
      .. "____73_e7X__d_______Xf_7_____________cAA"
    local data = base64.decode_url(s)
    local obj = AllowedVendors.new(data, { targetVendors = { 284 } })
    assert.is_not_nil(obj)
    assert.is_true(obj.vendorAllowed[284])
    -- And should not have others
    assert.is_nil(obj.vendorAllowed[1])
  end)

  it("fails on invalid segment type", function()
    local raw = string.char(0x20, 0x00, 0xA0) -- Type 1
    local obj, err = AllowedVendors.new(raw)
    assert.is_nil(obj)
    assert.match("invalid segment type", err)
  end)
end)

describe("Structural coverage", function()
  local base_string = "CP188cAQKFpAAAHABBENBSFsAP_gAEPgAAiQKqNX_H__bW9r8X73aft0eY1P9_j77uQxBhfJE-4"
    .. "FzLvW_JwXx2ExNA36tqIKmRIEu3bBIQNlHJHUTVigaogVryHMak2cpTNKJ6BkiFMRM2dYCF5vm4tj-QKY5_r993dx2D"
    .. "-t_dv83dzyz81Hn3f5_2e0eLCdQ5-tDfv9bROb-9IPd_78v4v8_l_rk2_eT1n_tevr7D_-ft8__XW_9_fff_9Pn_-uB"
    .. "-_3_vf_EFUwCTDQqIA-wJCQg0DCKBACoKwgIoFAQAAJA0QEAJgwKdgYALrCRACAFAAMEAIAAQZAAgAAAgAQiACQAoEA"
    .. "AEAgUAAYAEAwEABAwAAgAsBAIAAQHQMUwIIFAsIEjMioUwIQoEggJbKhBICgQVwhCLPAIgERMFAAgAAAVgACAsFgcSS"
    .. "AlQkECUG0AABAAgFEIFQgk9MAAwJmy1B4MG0ZWmAYPmCRDTAMgCIIyEAAAA.f_wACHwAAAAA"

  it("Parser:to_table includes all segments", function()
    local parser = tcf.new(base_string)
    local tbl = parser:to_table()
    assert.are.equal(2, tbl.version)
    assert.are.equal(7, tbl.cmpId)
    assert.is_not_nil(tbl.vendorConsents)
  end)

  it("Core:to_table includes tc_string", function()
    local parser = tcf.new(base_string)
    local tbl = parser._core:to_table()
    assert.are.equal(base_string, tbl.tc_string)
  end)

  it("Parser handles metadata and predicates", function()
    local parser = tcf.new(base_string)
    assert.are.equal(base_string, parser.tc_string)
    assert.are.equal(0, #parser.warnings)
    assert.is_true(parser.is_v22_plus)
    assert.is_true(parser.is_v23)
  end)
end)

describe("Robustness and nil-safety", function()
  -- 22 base64url 'A's decode to 16 zero bytes (132 bits, with 4 leftover
  -- bits discarded). policyVersion lives at bit offset 132, so reading it
  -- needs byte 17 -- which doesn't exist. In lenient mode the bitstream
  -- read returns nil and the predicates must not throw.
  local truncated_core = string.rep("A", 22)

  -- Same valid TC string used by the Structural coverage block above.
  local base_string = "CP188cAQKFpAAAHABBENBSFsAP_gAEPgAAiQKqNX_H__bW9r8X73aft0eY1P9_j77uQxBhfJE-4"
    .. "FzLvW_JwXx2ExNA36tqIKmRIEu3bBIQNlHJHUTVigaogVryHMak2cpTNKJ6BkiFMRM2dYCF5vm4tj-QKY5_r993dx2D"
    .. "-t_dv83dzyz81Hn3f5_2e0eLCdQ5-tDfv9bROb-9IPd_78v4v8_l_rk2_eT1n_tevr7D_-ft8__XW_9_fff_9Pn_-uB"
    .. "-_3_vf_EFUwCTDQqIA-wJCQg0DCKBACoKwgIoFAQAAJA0QEAJgwKdgYALrCRACAFAAMEAIAAQZAAgAAAgAQiACQAoEA"
    .. "AEAgUAAYAEAwEABAwAAgAsBAIAAQHQMUwIIFAsIEjMioUwIQoEggJbKhBICgQVwhCLPAIgERMFAAgAAAVgACAsFgcSS"
    .. "AlQkECUG0AABAAgFEIFQgk9MAAwJmy1B4MG0ZWmAYPmCRDTAMgCIIyEAAAA.f_wACHwAAAAA"

  it(
    "is_v22_plus and is_v23 are false when policyVersion is unavailable",
    function()
      local parser = tcf.new(truncated_core)
      assert.is_not_nil(parser)
      assert.is_nil(parser.policyVersion)
      assert.is_false(parser.is_v22_plus)
      assert.is_false(parser.is_v23)
    end
  )

  it(
    "Validator min_tcf_policy_version fails closed when policyVersion is nil",
    function()
      local parser = tcf.new(truncated_core)
      local v = Validator.new({ vendor_id = 1, min_tcf_policy_version = 5 })
      local ok, err = v:validate(parser)
      assert.is_false(ok)
      assert.match("policy version", err)
    end
  )

  it("Validator:validate does not mutate the overrides table", function()
    local v = Validator.new({ vendor_id = 284 })
    local overrides = { vendor_id = 3, consent_purpose_ids = { 1 } }
    v:validate(base_string, overrides)
    assert.is_nil(
      getmetatable(overrides),
      "overrides should not have a metatable installed"
    )
    -- The overrides table itself must be byte-for-byte unchanged.
    assert.are.same({ vendor_id = 3, consent_purpose_ids = { 1 } }, overrides)
  end)

  it("Parser strict mode rejects tc strings with empty segments", function()
    local p1, err1 = tcf.new("ABC..DEF", { strict = true })
    assert.is_nil(p1)
    assert.match("malformed tc string", err1)

    local p2, err2 = tcf.new(".ABC", { strict = true })
    assert.is_nil(p2)
    assert.match("malformed tc string", err2)

    local p3, err3 = tcf.new("ABC.", { strict = true })
    assert.is_nil(p3)
    assert.match("malformed tc string", err3)
  end)
end)
