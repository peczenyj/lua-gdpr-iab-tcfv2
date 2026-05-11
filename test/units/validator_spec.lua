local Validator = require("gdpr.iab.tcfv2.validator")

describe("Validator", function()
  local tc_string = "CP188cAQKFpAAAHABBENBSFsAP_gAEPgAAiQKqNX_H__bW9r8X73aft0eY1P9_j77uQxBhfJE-4"
    .. "FzLvW_JwXx2ExNA36tqIKmRIEu3bBIQNlHJHUTVigaogVryHMak2cpTNKJ6BkiFMRM2dYCF5vm4tj-QKY5_r993dx2D"
    .. "-t_dv83dzyz81Hn3f5_2e0eLCdQ5-tDfv9bROb-9IPd_78v4v8_l_rk2_eT1n_tevr7D_-ft8__XW_9_fff_9Pn_-uB"
    .. "-_3_vf_EFUwCTDQqIA-wJCQg0DCKBACoKwgIoFAQAAJA0QEAJgwKdgYALrCRACAFAAMEAIAAQZAAgAAAgAQiACQAoEA"
    .. "AEAgUAAYAEAwEABAwAAgAsBAIAAQHQMUwIIFAsIEjMioUwIQoEggJbKhBICgQVwhCLPAIgERMFAAgAAAVgACAsFgcSS"
    .. "AlQkECXUG0AABAAgFEIFQgk9MAAwJmy1B4MG0ZWmAYPmCRDTAMgCIIyEAAAA.f_wACHwAAAAA"

  -- String with Publisher Restrictions (Purpose 9 restricted for many vendors)
  local restricted_string = "CP_1wcAQO4KMAAHABBENBiFsAP_gAEPAAAAAK8tX_H__bW9r8X736ft0eY1f9_j77uQxBhfJk-4"
    .. "FzLvW_JwX32E7NA36tqYKmRIEu3bBIQNlHJHUTVigaogVryHMak2cpTtKJ6BkiFMRe2dYCF5vm4tj-QKY5_r993d52R"
    .. "-9_dv83dzyz81nv3f9_-e1eLCdQ5-tDfv9bROb-9IP9_78v4v8_t_rk2_eT1n_tevr7D_-ft___X3_9_fff_9Pn__ul"
    .. "-_X__f_n37v942CTIBJhoVEAXYEhAQKBhFAgBEFYQEUCgAAAAgYICAAgYFOQMAF1gAgAACgAECAEAAIMAAQAAAQAIRAB"
    .. "IAUCAAAAQCAAAAAAQCAAgYAAQAWAgEAAIBoGKIEAAgSECRARAKYEAECQQEtlAgkBQIKYQBBlgAACImAAAAAAAKwAAAWC"
    .. "gGAJASsSCBJCDaAAAgAQCiECoQSeGAMQgAwABBXklABgACCvI6ADAAEFeSkAGAAIK8hIAMAAQV5LQAYAAgryAA.f_wAC"
    .. "HwAAAAA"

  -- String with Disclosed Vendors segment (Segment Type 1)
  local disclosed_string = "CQa0q5gQa0q5gAcABBESCEFsAP_gAEPgAChQLutR_G__bWlr-bb3aftkeYxP9_hr7sQxBgbJk24"
    .. "FzLvW7JwXx2E5NAzatqIKmRIAu3TBIQNlHJHURVCgKIgVryDMaEyUoTNKJ6BkiFMRI2NYCF5vm4tjWQCY5vr99lc1mB"
    .. "-N7dr82dzyy6hHn3a5_2S1WJCdIYetDfv8ZBKT-9IEd_x8v4v4_F7pE2-eS1n_pGvp6j9-YnM_dBmxt-bSffzPn__rl"
    .. "_e7X_vd_n37v94XH77v____f_-7___2YLvAAmGhUQRlkQIBAoGEECABQVhABQIAgAASBogIATBgU5AwAXWEyAEAKAAYI"
    .. "AQAAgwABAAAJAAhEAFABAIAAIBAoAAwAIAgIAGBgADABYiAQAAgOgYpgQQCBYAJGZVBpgSgAJBAS2VCCQDAgrhCEWeAQ"
    .. "QIiYKAAAEAAoAAAB4LAQkkBKxIIAuIJoAACAAAKIECBFIWYAgqDNFoLwJOoyNMAwfMEySnQZAEwRkZJsQm_CYeKQohQQ"
    .. "5AbFLMAdMAA.f_wACHwAAAAA.ILvNR_G__bXlv-bb36ftkeYxf9_hr7sQxBgbJs24FzLvW7JwX32E7NEzatqYKmRIEu3"
    .. "bBIQNtHJjURVChKIgVrzDsaEyUoTtKJ-BkiHMRY2NYCFxvm4tjWQCZ5vr_91d9mT-N7dr-2dzyy7hnv3a9_-S1WJidKY"
    .. "etHfv8ZBKT-_IU9_x-_4v4_N7pE2-eS1v_tGvt639-4vP_dpvxt-7yffz____73_e7X__d_______Xf_7__________"
    .. "___cAA"

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
    assert.are.equal("vendor 3 not allowed for purpose 1 (consent)", err)
  end)

  it("fails when purpose has no consent", function()
    local v = Validator.new({
      vendor_id = 284,
      consent_purpose_ids = { 24 }, -- Purpose 24 has no consent
    })
    local ok, err = v:validate(tc_string)
    assert.is_false(ok)
    assert.are.equal("vendor 284 not allowed for purpose 24 (consent)", err)
  end)

  it("respects runtime overrides", function()
    local v = Validator.new({
      vendor_id = 284,
    })
    -- Override vendor_id to one that doesn't have consent
    local ok, err =
      v:validate(tc_string, { vendor_id = 3, consent_purpose_ids = { 1 } })
    assert.is_false(ok)
    assert.are.equal("vendor 3 not allowed for purpose 1 (consent)", err)
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
    assert.are.equal("legitimate interest not permitted for purpose 1", err)
  end)

  it("enforces LI carve-out for purposes 3-6 in TCF v2.2+", function()
    -- tc_string is policy version 5 (TCF v2.3), so the carve-out fires for
    -- pids 3-6. Matches Perl's _li_carve_out_applies.
    for _, pid in ipairs({ 3, 4, 5, 6 }) do
      local v = Validator.new({
        vendor_id = 284,
        legitimate_interest_purpose_ids = { pid },
      })
      local ok, err = v:validate(tc_string)
      assert.is_false(ok, "expected failure for LI on purpose " .. pid)
      assert.are.equal(
        string.format("legitimate interest not permitted for purpose %d", pid),
        err
      )
    end
  end)

  it("enforces min_tcf_policy_version", function()
    local v = Validator.new({
      vendor_id = 284,
      min_tcf_policy_version = 10,
    })
    local ok, err = v:validate(tc_string)
    assert.is_false(ok)
    assert.match(
      "TC string policy version %d+ is below required minimum 10",
      err
    )
  end)

  describe("Flexible Purposes", function()
    it(
      "switches to Legitimate Interest when Consent is restricted (Type 2)",
      function()
        -- In restricted_string, Purpose 9 has a Type 2 restriction (Require LI) for many vendors.
        -- We'll check vendor 284, purpose 9.
        local v = Validator.new({
          vendor_id = 284,
          consent_purpose_ids = { 9 },
          flexible_purpose_ids = { 9 },
        })
        local ok, err = v:validate(restricted_string)
        -- It should pass because 284 has LI for Purpose 9 and it is flexible.
        assert.is_true(ok, err)
      end
    )

    it("fails when flexible purpose cannot establish either basis", function()
      local v = Validator.new({
        vendor_id = 99999, -- Non-existent vendor
        consent_purpose_ids = { 1 },
        flexible_purpose_ids = { 1 },
      })
      local ok, err = v:validate(tc_string)
      assert.is_false(ok)
      assert.match("vendor 99999 not allowed for purpose 1 %(consent%)", err)
    end)
  end)

  describe("Constructor coherence", function()
    it("errors when a purpose is in both consent and LI lists", function()
      assert.has_error(
        function()
          Validator.new({
            vendor_id = 284,
            consent_purpose_ids = { 1, 2 },
            legitimate_interest_purpose_ids = { 2, 7 },
          })
        end,
        "purpose 2 cannot be in both consent_purpose_ids and legitimate_interest_purpose_ids"
      )
    end)

    it("errors when a flexible purpose is in neither basis list", function()
      assert.has_error(
        function()
          Validator.new({
            vendor_id = 284,
            consent_purpose_ids = { 1 },
            flexible_purpose_ids = { 9 }, -- 9 isn't in consent or LI
          })
        end,
        "flexible purpose 9 must also appear in consent_purpose_ids or legitimate_interest_purpose_ids"
      )
    end)
  end)

  describe("validate_all accumulates failures", function()
    it("returns every failure from the consent loop", function()
      local v = Validator.new({
        vendor_id = 99999, -- guaranteed miss across the corpus
        consent_purpose_ids = { 1, 2, 3 },
      })
      local ok, errs = v:validate_all(tc_string)
      assert.is_false(ok)
      assert.are.equal("table", type(errs))
      assert.are.equal(3, #errs)
    end)
  end)

  describe("strict_legal_basis decoupled from parser strict", function()
    it(
      "errors on out-of-range purpose id when strict_legal_basis is true",
      function()
        local v = Validator.new({
          vendor_id = 284,
          consent_purpose_ids = { 25 }, -- 25 is outside the TCF 1..24 range
          strict_legal_basis = true,
        })
        assert.has_error(function()
          v:validate(tc_string)
        end)
      end
    )

    it("returns false silently on out-of-range pid by default", function()
      local v = Validator.new({
        vendor_id = 284,
        consent_purpose_ids = { 25 },
      })
      local ok, err = v:validate(tc_string)
      assert.is_false(ok)
      assert.match("vendor 284 not allowed for purpose 25 %(consent%)", err)
    end)
  end)

  describe("Disclosed Vendors", function()
    it("verifies presence in disclosed vendors segment", function()
      local v = Validator.new({
        vendor_id = 284,
        verify_disclosed_vendors = true,
      })
      local ok, err = v:validate(disclosed_string)
      assert.is_true(ok, err)
    end)

    it("fails when vendor is missing from disclosed vendors segment", function()
      local v = Validator.new({
        vendor_id = 12345, -- Not in the segment
        verify_disclosed_vendors = true,
      })
      local ok, err = v:validate(disclosed_string)
      assert.is_false(ok)
      assert.are.equal("vendor 12345 not disclosed", err)
    end)

    it("enforces mandatory disclosed segment in TCF v2.3+", function()
      local v = Validator.new({
        vendor_id = 284,
        verify_disclosed_vendors = true,
        min_tcf_policy_version = 5,
      })
      -- tc_string is policy version 5 (TCF v2.3) with no Disclosed Vendors
      -- segment. Per the Perl reference (Validator.pm _check_disclosed), the
      -- missing-mandatory-segment failure only fires when the caller
      -- explicitly demands min_tcf_policy_version >= 5; otherwise absence is
      -- silently tolerated. This test verifies that gating.
      local ok, err = v:validate(tc_string)
      assert.is_false(ok)
      assert.are.equal("missing disclosed vendors segment", err)
    end)
  end)
end)
