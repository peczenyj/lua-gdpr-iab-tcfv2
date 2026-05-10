local M = {
  PRECISE_GEOLOCATION = 1,
  SCAN_DEVICE_CHARACTERISTICS = 2,
}

local names = {}
for k, v in pairs(M) do
  names[v] = k
end

setmetatable(M, {
  __index = function(_, key)
    return names[key]
  end,
})

return M
