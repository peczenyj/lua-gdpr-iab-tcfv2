--- Main entry point for the IAB TCF v2.x parser and validator.
-- @module gdpr.iab.tcfv2
-- @author Tiago Peczenyj
-- @license MIT

local Parser = require("gdpr.iab.tcfv2.parser")
local Validator = require("gdpr.iab.tcfv2.validator")

local M = {}

--- Exposes the Validator class.
-- @table Validator
M.Validator = Validator

--- Creates a new TCF Parser instance from a TC string.
-- @function new
-- @param tc_string string The encoded IAB TCF v2.x consent string.
-- @param[opt] options table Configuration options.
-- @return table|nil Parser object or nil on error.
function M.new(tc_string, options)
  return Parser.new(tc_string, options)
end

return M
