local M = {}

local chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local chars_url = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_'

local function build_decode_map(alphabet)
    local map = {}
    for i = 1, #alphabet do
        map[alphabet:sub(i, i)] = i - 1
    end
    return map
end

local decode_map_url = build_decode_map(chars_url)

function M.decode_url(input)
    -- Remove padding and invalid chars
    input = input:gsub('[^%w%-_]', '')
    
    local length = #input
    local output = {}
    local buffer = 0
    local bits = 0
    
    for i = 1, length do
        local char = input:sub(i, i)
        local val = decode_map_url[char]
        if not val then return nil, "invalid character in base64url string" end
        
        buffer = (buffer * 64) + val
        bits = bits + 6
        
        if bits >= 8 then
            bits = bits - 8
            local byte = math.floor(buffer / (2^bits))
            table.insert(output, string.char(byte % 256))
            buffer = buffer % (2^bits)
        end
    end
    
    return table.concat(output)
end

return M
