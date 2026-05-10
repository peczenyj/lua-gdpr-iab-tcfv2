local json = require("test.vendor.json")

local M = {}

function M.get_corpus_path()
    return "test/corpus/gdpr_subset.txt"
end

function M.get_golden_path()
    return "test/corpus/golden.jsonl"
end

function M.read_golden(callback)
    local path = M.get_golden_path()
    local f = io.open(path, "r")
    if not f then return nil, "failed to open " .. path end
    
    for line in f:lines() do
        if line ~= "" then
            local status, data = pcall(json.decode, line)
            if status then
                callback(data)
            else
                print("JSON Decode Error: " .. tostring(data))
                print("Line: [" .. line .. "]")
            end
        end
    end
    
    f:close()
end

return M
