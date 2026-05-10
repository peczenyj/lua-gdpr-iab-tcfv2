local M = {
  NOT_ALLOWED = 0,
  REQUIRE_CONSENT = 1,
  REQUIRE_LEGITIMATE_INTEREST = 2,
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
