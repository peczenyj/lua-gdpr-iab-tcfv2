local M = {
    INFO_STORAGE_ACCESS         = 1,
    SELECT_BASIC_ADS            = 2,
    CREATE_PERSONALIZED_ADS     = 3,
    SELECT_PERSONALIZED_ADS     = 4,
    CREATE_PERSONALIZED_CONTENT = 5,
    SELECT_PERSONALIZED_CONTENT = 6,
    MEASURE_AD_PERFORMANCE      = 7,
    MEASURE_CONTENT_PERFORMANCE = 8,
    MARKET_RESEARCH             = 9,
    DEVELOP_IMPROVE             = 10,
    LINK_DEVICES                = 11,
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
