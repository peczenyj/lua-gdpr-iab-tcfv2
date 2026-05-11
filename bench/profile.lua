local tcf = require("gdpr.iab.tcfv2")
local harness = require("test.reference.golden_harness")

-- Check if LuaJIT and jit.p are available
local has_jit, _ = pcall(require, "jit")
if not has_jit then
  print("Error: LuaJIT is required for profiling.")
  os.exit(1)
end

local has_prof, prof = pcall(require, "jit.p")
if not has_prof then
  print("Error: jit.p module not found. Is this a full LuaJIT installation?")
  os.exit(1)
end

-- Workload: Multiple passes of the full corpus
local function run_workload(iterations)
  iterations = iterations or 50
  local count = 0
  for _ = 1, iterations do
    harness.read_golden(function(data)
      if data.expect_failure then
        return
      end
      local p = tcf.new(data.tc_string)
      -- Force some lazy lookups to stress the decoders
      local _ = p.vendorConsents[284]
      local _ = p.purposeConsents[1]
      local _ = p.publisherRestrictions
      count = count + 1
    end)
  end
  return count
end

print("Starting LuaJIT Profiling (Sample rate: 10ms)...")
print("Workload: 50 passes of the Golden Corpus (~50k parses)")
print(string.rep("-", 60))

-- Start Profiling
-- Modes:
-- v: VM state
-- l: Line level
-- f: Function names
-- m: Minimum percentage to report
prof.start("vl", "bench/profile_results.txt")

local start = os.clock()
local total = run_workload(50)
local duration = os.clock() - start

prof.stop()

print(string.format("Profiling completed in %.2f seconds.", duration))
print(string.format("Total parses executed: %d", total))
print("Results saved to: bench/profile_results.txt")
print(string.rep("-", 60))

-- Read and display top results
local f = io.open("bench/profile_results.txt", "r")
if f then
  print("Top Performance Hotspots:")
  local line_count = 0
  for line in f:lines() do
    if line_count < 20 then
       print(line)
    end
    line_count = line_count + 1
  end
  f:close()
end
