local json = require("test.vendor.json")

local M = {}

function M.get_corpus_path()
    return "test/corpus/gdpr_subset.txt"
end

function M.get_golden_path()
    return "test/corpus/golden.jsonl.gz"
end

function M.read_golden(callback)
    local path = M.get_golden_path()
    -- Use zcat to read gzipped file without Lua dependencies (Linux/Unix only)
    local f = io.popen("zcat " .. path)
    if not f then return nil, "failed to open " .. path end
    
    for line in f:lines() do
        local data = json.decode(line)
        callback(data)
    end
    
    f:close()
end

return M
