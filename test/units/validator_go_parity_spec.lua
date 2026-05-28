local Validator = require("gdpr.iab.tcfv2.validator")

-- These tests pin the Lua Validator to the Go lib-gdpr "redesign" branch
-- strict-path semantics (validator/validator_strict.go + the surrounding
-- gates in validator/validator.go), the same target the Perl reference
-- mirrors in t/18-go-parity.t. Each block names the Go construct it mirrors.

-- The validator reads plain fields off the parser table, so a lightweight stub
-- exposing only the accessors a given rule consults keeps the date / policy /
-- restriction gates deterministic and independent of any fixture string.

-- created is stored in DECISECONDS (the raw TCF Created field), so the
-- deadline constant is the seconds value * 10.
local DEADLINE = 17722368000 -- 1772236800 * 10 == 2026-02-28T00:00:00Z

-- Build a minimal parser stub. Restriction maps are keyed by purpose then
-- vendor, matching parser.publisherRestrictions.
local function stub(fields)
  local p = {
    publisherRestrictions = fields.publisherRestrictions or {},
    vendorConsents = fields.vendorConsents or {},
    vendorLegitimateInterests = fields.vendorLegitimateInterests or {},
    purposeConsents = fields.purposeConsents or {},
    purposeLegitimateInterests = fields.purposeLegitimateInterests or {},
  }
  p.created = fields.created
  p.policyVersion = fields.policyVersion
  p.vendorDisclosed = fields.vendorDisclosed
  return p
end

-- A flexible-purpose stub: rejects every bitfield decision and reports at most
-- one publisher restriction type, so the effective-basis reason mapping can be
-- exercised in isolation (the LI/consent bitfields are empty, so the only path
-- to "allowed" is closed and we always reach the failure reason).
local function flex_stub(policy_version, restriction)
  local pr = {}
  if restriction then
    -- apply the restriction to every purpose used below, vendor 7
    pr = setmetatable({}, {
      __index = function()
        return { [7] = restriction }
      end,
    })
  end
  return stub({ policyVersion = policy_version, publisherRestrictions = pr })
end

describe("Validator Go-parity", function()
  describe(
    "#1 min>=5 auto-enables verify_disclosed (Go New: ||= min>=5)",
    function()
      it("auto-enables when the floor is 5", function()
        local v = Validator.new({ vendor_id = 10, min_tcf_policy_version = 5 })
        assert.is_true(v.config.verify_disclosed_vendors)
      end)

      it("leaves it off below 5", function()
        local v = Validator.new({ vendor_id = 10, min_tcf_policy_version = 4 })
        assert.is_falsy(v.config.verify_disclosed_vendors)
      end)

      it("does not mutate the caller's config table", function()
        local cfg = { vendor_id = 10, min_tcf_policy_version = 5 }
        Validator.new(cfg)
        assert.is_nil(cfg.verify_disclosed_vendors)
      end)
    end
  )

  describe(
    "#1 mandatory DV runs regardless of verify (yieldMandatoryDisclosedVendors)",
    function()
      it(
        "policy>=5 && min>=5 && DV absent => missing segment, verify off",
        function()
          local v = Validator.new({ vendor_id = 10 })
          local failures = {}
          -- pre-deadline, policy 5, no DV segment, verify explicitly off.
          v:_check_disclosed(
            stub({ created = DEADLINE - 1, policyVersion = 5 }),
            10,
            false,
            5,
            failures
          )
          assert.are.equal(1, #failures)
          assert.are.equal("missing disclosed vendors segment", failures[1])
        end
      )
    end
  )

  describe(
    "#1 verify auto-enable surfaces 'not disclosed' when DV present",
    function()
      it("min>=5 auto-enables verify => undisclosed vendor fails", function()
        local v = Validator.new({ vendor_id = 10, min_tcf_policy_version = 5 })
        local failures = {}
        -- DV segment present, vendor 10 NOT disclosed, pre-deadline.
        v:_check_disclosed(
          stub({
            created = DEADLINE - 1,
            policyVersion = 5,
            vendorDisclosed = { [5] = true },
          }),
          10,
          v.config.verify_disclosed_vendors,
          5,
          failures
        )
        assert.are.equal("vendor 10 not disclosed", failures[1])
      end)
    end
  )

  describe(
    "#2 policy-based missing DV requires the string's own policy>=5 (Go branch b)",
    function()
      it(
        "policy<5 string does not trigger the policy-based mandatory DV",
        function()
          local v = Validator.new({ vendor_id = 10 })
          local failures = {}
          -- min floor 5, verify on, but the STRING is policy 2 and DV absent.
          v:_check_disclosed(
            stub({ created = DEADLINE - 1, policyVersion = 2 }),
            10,
            true,
            5,
            failures
          )
          assert.are.equal(0, #failures)
        end
      )
    end
  )

  describe(
    "#5 single policy-version failure when v2.3 and floor both apply",
    function()
      it("emits exactly one failure (v2.3 rule wins, then returns)", function()
        local v = Validator.new({ vendor_id = 10 })
        local failures = {}
        -- post-deadline, policy 2, floor 5.
        v:_check_policy_version(
          stub({ created = DEADLINE + 1, policyVersion = 2 }),
          5,
          failures
        )
        assert.are.equal(1, #failures)
        assert.are.equal(
          "post-deadline string requires policy version >= 5",
          failures[1]
        )
      end)
    end
  )

  describe(
    "#4 v2.3 deadline boundary is strictly-after (Go .After())",
    function()
      it(
        "created == deadline is not subject to date-based v2.3 enforcement",
        function()
          local v = Validator.new({ vendor_id = 10 })
          local failures = {}
          local at = stub({ created = DEADLINE, policyVersion = 2 })
          v:_check_policy_version(at, nil, failures)
          v:_check_disclosed(at, 10, false, nil, failures)
          assert.are.equal(0, #failures)
        end
      )

      it("created == deadline + 1 fires both date-based rules", function()
        local v = Validator.new({ vendor_id = 10 })
        local failures = {}
        local after = stub({ created = DEADLINE + 1, policyVersion = 2 })
        v:_check_policy_version(after, nil, failures)
        v:_check_disclosed(after, 10, false, nil, failures)
        local seen = {}
        for _, m in ipairs(failures) do
          seen[m] = true
        end
        assert.is_true(
          seen["post-deadline string requires policy version >= 5"]
        )
        assert.is_true(
          seen["post-deadline string requires disclosed vendors segment"]
        )
      end)
    end
  )

  describe(
    "#3 flexible purpose + NotAllowed restriction => dedicated reason",
    function()
      it(
        "NotAllowed on a flexible consent purpose surfaces the restriction reason",
        function()
          local v = Validator.new({ vendor_id = 7 })
          local failures = {}
          -- NotAllowed (type 0) on purpose 5 for vendor 7.
          local p = stub({
            policyVersion = 5,
            publisherRestrictions = { [5] = { [7] = 0 } },
          })
          v:_check_consent_purposes(
            p,
            7,
            false,
            failures,
            false,
            { 5 },
            { [5] = true }
          )
          assert.are.equal(1, #failures)
          assert.are.equal(
            "publisher restriction: purpose 5 not allowed (vendor 7)",
            failures[1]
          )
        end
      )
    end
  )

  describe(
    "#2 flexible effective-basis reason mapping (runFlexibleCheck)",
    function()
      it("carve-out P1 in the LI list flips the basis to consent", function()
        local v = Validator.new({ vendor_id = 7 })
        local failures = {}
        v:_check_li_purposes(
          flex_stub(2),
          7,
          false,
          failures,
          false,
          { 1 },
          { [1] = true }
        )
        assert.are.equal(
          "vendor 7 not allowed for purpose 1 (consent)",
          failures[1]
        )
      end)

      it(
        "LI-list purpose with RequireConsent restriction => consent reason",
        function()
          local v = Validator.new({ vendor_id = 7 })
          local failures = {}
          v:_check_li_purposes(
            flex_stub(2, 1), -- RequireConsent
            7,
            false,
            failures,
            false,
            { 7 },
            { [7] = true }
          )
          assert.are.equal(
            "vendor 7 not allowed for purpose 7 (consent)",
            failures[1]
          )
        end
      )

      it(
        "consent-list purpose with RequireLI restriction => LI reason",
        function()
          local v = Validator.new({ vendor_id = 7 })
          local failures = {}
          v:_check_consent_purposes(
            flex_stub(2, 2), -- RequireLegitimateInterest
            7,
            false,
            failures,
            false,
            { 7 },
            { [7] = true }
          )
          assert.are.equal(
            "vendor 7 not allowed for purpose 7 (legitimate interest)",
            failures[1]
          )
        end
      )

      it("carve-out P1 + RequireLI restriction => carve-out reason", function()
        local v = Validator.new({ vendor_id = 7 })
        local failures = {}
        v:_check_li_purposes(
          flex_stub(2, 2), -- RequireLI, but the spec carve-out outranks it
          7,
          false,
          failures,
          false,
          { 1 },
          { [1] = true }
        )
        assert.are.equal(
          "legitimate interest not permitted for purpose 1",
          failures[1]
        )
      end)
    end
  )

  describe("global vendor gate (ReasonVendorNotAllowed)", function()
    it("fires when the vendor has neither consent nor LI", function()
      local v = Validator.new({ vendor_id = 42 })
      local failures = {}
      local fired = v:_check_vendor_gate(stub({}), 42, failures)
      assert.is_true(fired)
      assert.are.equal(
        "vendor 42 not allowed (no consent or legitimate interest)",
        failures[1]
      )
    end)

    it("passes when the vendor has legitimate interest only", function()
      local v = Validator.new({ vendor_id = 42 })
      local failures = {}
      local fired = v:_check_vendor_gate(
        stub({ vendorLegitimateInterests = { [42] = true } }),
        42,
        failures
      )
      assert.is_false(fired)
      assert.are.equal(0, #failures)
    end)
  end)
end)
