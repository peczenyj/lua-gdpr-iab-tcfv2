--- Publisher Restriction types for IAB TCF v2.x.
-- @module gdpr.iab.tcfv2.constants.restriction_type
-- @author Tiago Peczenyj
-- @license MIT

local M = {
  [0] = "Not Allowed",
  [1] = "Require Consent",
  [2] = "Require Legitimate Interest",
}

-- Bi-directional mapping
for k, v in pairs(M) do
  M[v] = k
end

return M
