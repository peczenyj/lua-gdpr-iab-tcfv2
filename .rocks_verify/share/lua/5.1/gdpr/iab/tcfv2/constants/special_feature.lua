--- Special Feature IDs and names for IAB TCF v2.x.
-- @module gdpr.iab.tcfv2.constants.special_feature
-- @author Tiago Peczenyj
-- @license MIT

local M = {
  [1] = "Use precise geolocation data",
  [2] = "Actively scan device characteristics for identification",
}

-- Bi-directional mapping
for k, v in pairs(M) do
  M[v] = k
end

return M
