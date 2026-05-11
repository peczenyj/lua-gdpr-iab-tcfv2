--- Purpose IDs and names for IAB TCF v2.x.
-- @module gdpr.iab.tcfv2.constants.purpose
-- @author Tiago Peczenyj
-- @license MIT

local M = {
  [1] = "Store and/or access information on a device",
  [2] = "Select basic ads",
  [3] = "Create a personalised ads profile",
  [4] = "Select personalised ads",
  [5] = "Create a personalised content profile",
  [6] = "Select personalised content",
  [7] = "Measure ad performance",
  [8] = "Measure content performance",
  [9] = "Apply market research to generate audience insights",
  [10] = "Develop and improve products",
}

-- Bi-directional mapping
for k, v in pairs(M) do
  M[v] = k
end

return M
