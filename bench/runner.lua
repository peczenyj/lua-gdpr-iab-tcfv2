local tcf = require("gdpr.iab.tcfv2")
local Validator = tcf.Validator
local harness = require("test.reference.golden_harness")

-- Use os.clock() for CPU time measurement
local function bench(name, fn, iterations)
  iterations = iterations or 10000
  local start = os.clock()
  for _ = 1, iterations do
    fn()
  end
  local duration = os.clock() - start
  local ops_sec = iterations / duration
  local latency_us = (duration / iterations) * 1000000

  print(
    string.format(
      "%-30s | %10.2f ops/s | %10.2f us/op",
      name,
      ops_sec,
      latency_us
    )
  )
end

-- Representative TC strings
local base_string =
  "CP188cAQKFpAAAHABBENBSFsAP_gAEPgAAiQKqNX_H__bW9r8X73aft0eY1P9_j77uQxBhfJE-4"
  .. "FzLvW_JwXx2ExNA36tqIKmRIEu3bBIQNlHJHUTVigaogVryHMak2cpTNKJ6BkiFMRM2dYCF5vm4tj-QKY5_r993dx2D"
  .. "-t_dv83dzyz81Hn3f5_2e0eLCdQ5-tDfv9bROb-9IPd_78v4v8_l_rk2_eT1n_tevr7D_-ft8__XW_9_fff_9Pn_-uB"
  .. "-_3_vf_EFUwCTDQqIA-wJCQg0DCKBACoKwgIoFAQAAJA0QEAJgwKdgYALrCRACAFAAMEAIAAQZAAgAAAgAQiACQAoEA"
  .. "AEAgUAAYAEAwEABAwAAgAsBAIAAQHQMUwIIFAsIEjMioUwIQoEggJbKhBICgQVwhCLPAIgERMFAAgAAAVgACAsFgcSS"
  .. "AlQkECUG0AABAAgFEIFQgk9MAAwJmy1B4MG0ZWmAYPmCRDTAMgCIIyEAAAA.f_wACHwAAAAA"

local complex_string =
  "CQa0zsAQa0zsAAHABBENCEFsAP_gAEPgACQgKhwLIAFAAWAA0ACoAFwAOAAgABaADIAGgARQAmABQAC2AGEANoAgIBBg"
  .. "EIAI4AVoA5AB3ADxAH6AScApoBnADTgG8AToAn8BTYC4QF5gMZAbmA44ByYEJAIzASNAkyBSUClYFQw.fXgAAGgAAAAA"
  .. ".IKhwLIAFAAWAA0ACoAFwAOAAgABaADIAGgARQAmABQAC2AGEANoAgIBBgEIAI4AVoA5AB3ADxAH6AScApoBnADTgG8A"
  .. "ToAn8BTYC4QF5gMZAbmA44ByYEJAIzASNAkyBSUClYFQw"

print(string.format("%-30s | %14s | %12s", "Benchmark", "Throughput", "Latency"))
print(string.rep("-", 65))

-- 1. Parser Benchmarks
bench("Parser: new (simple)", function()
  tcf.new(base_string)
end)

bench("Parser: new (complex)", function()
  tcf.new(complex_string)
end)

local p = tcf.new(base_string)
bench("Parser: access vendor field", function()
  local _ = p.vendorConsents[284]
end)

bench("Parser: to_table", function()
  p:to_table()
end)

-- 2. Validator Benchmarks
local v = Validator.new({
  vendor_id = 284,
  consent_purpose_ids = { 1, 2, 3 },
})

bench("Validator: validate (fail-fast)", function()
  v:validate(base_string)
end)

bench("Validator: validate_all", function()
  v:validate_all(base_string)
end)

-- 3. Optimization Benchmarks
bench("Parser: optimized VID", function()
  tcf.new(base_string, { targetVendors = { 284 } })
end)

local p_opt = tcf.new(base_string, { targetVendors = { 284 } })
bench("Validator: use optimized parser", function()
  v:validate(p_opt)
end)

-- 4. Corpus Scan Benchmark
local function run_corpus_scan()
  local count = 0
  harness.read_golden(function(data)
    if data.expect_failure then
      return
    end
    tcf.new(data.tc_string)
    count = count + 1
  end)
  return count
end

-- We measure one full pass of the 1024 strings
local start = os.clock()
local total_parsed = run_corpus_scan()
local duration = os.clock() - start
local ops_sec = total_parsed / duration
local latency_us = (duration / total_parsed) * 1000000

print(
  string.format(
    "%-30s | %10.2f ops/s | %10.2f us/op (%d strings)",
    "Corpus: Sequential Scan",
    ops_sec,
    latency_us,
    total_parsed
  )
)
