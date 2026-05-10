--- Segment decoder for Publisher TC (Type 3).
-- @classmod gdpr.iab.tcfv2.publisher_tc
-- @author Tiago Peczenyj
-- @license MIT

local BitStream = require("gdpr.iab.tcfv2.bitstream")
local common = require("gdpr.iab.tcfv2.common")

local PublisherTC = {}
PublisherTC.__index = PublisherTC

--- Creates a new Publisher TC segment instance.
-- @function new
-- @param decoded_data string Raw binary data for the segment.
-- @param[opt] options table Configuration options.
-- @return table|nil PublisherTC instance or nil on error.
function PublisherTC.new(decoded_data, options)
  local bs = BitStream.new(decoded_data)
  local segment_type = bs:read_int(3)

  if segment_type ~= 3 then
    return nil,
      "invalid segment type for publisher tc: " .. tostring(segment_type)
  end

  local pubPurposesConsent = common.decode_bitfield_fixed(bs, nil, 24)
  local pubPurposesLITransparency = common.decode_bitfield_fixed(bs, nil, 24)

  local numCustom_val = bs:read_int(6)
  local numCustomPurposes = numCustom_val or 0
  local customPurposesConsent =
    common.decode_bitfield_fixed(bs, nil, numCustomPurposes)
  local customPurposesLITransparency =
    common.decode_bitfield_fixed(bs, nil, numCustomPurposes)

  local self = setmetatable({
    pubPurposesConsent = pubPurposesConsent,
    pubPurposesLITransparency = pubPurposesLITransparency,
    numCustomPurposes = numCustomPurposes,
    customPurposesConsent = customPurposesConsent,
    customPurposesLITransparency = customPurposesLITransparency,
  }, PublisherTC)

  return self
end

--- Converts publisher TC segment fields to a plain table.
-- @function to_table
-- @return table
function PublisherTC:to_table()
  return {
    pubPurposesConsent = self.pubPurposesConsent,
    pubPurposesLITransparency = self.pubPurposesLITransparency,
    numCustomPurposes = self.numCustomPurposes,
    customPurposesConsent = self.customPurposesConsent,
    customPurposesLITransparency = self.customPurposesLITransparency,
  }
end

return PublisherTC
