local BitStream = require("gdpr.iab.tcfv2.bitstream")

local Core = {}
Core.__index = Core

local OFFSETS = {
  VERSION = 0,
  CREATED = 6,
  LAST_UPDATED = 42,
  CMP_ID = 78,
  CMP_VERSION = 90,
  CONSENT_SCREEN = 102,
  CONSENT_LANGUAGE = 108,
  VENDOR_LIST_VERSION = 120,
  POLICY_VERSION = 132,
  SERVICE_SPECIFIC = 138,
  USE_NON_STANDARD_STACKS = 139,
  SPECIAL_FEATURE_OPT_IN = 140,
  PURPOSE_CONSENT = 152,
  PURPOSE_LI = 176,
  PURPOSE_ONE_TREATMENT = 200,
  PUBLISHER_COUNTRY_CODE = 201,
  VENDOR_CONSENT = 213,
}

local function decode_char6(bs)
  local val = bs:read_int(6)
  if not val then
    return nil
  end
  return string.char(string.byte("A") + val)
end

local function decode_language(bs)
  local c1 = decode_char6(bs)
  local c2 = decode_char6(bs)
  if not c1 or not c2 then
    return nil
  end
  return c1 .. c2
end

local function decode_bitfield_fixed(bs, start_offset, length)
  bs:seek(start_offset)
  local res = {}
  for i = 1, length do
    res[i] = bs:read_bool()
  end
  return res
end

local function decode_vendor_bitfield(bs, start_offset, max_id, target_vendors)
  local res = {}
  if target_vendors then
    local target_map = {}
    for _, id in ipairs(target_vendors) do
      target_map[id] = true
    end

    for i = 1, max_id do
      local val = bs:read_bool()
      if target_map[i] then
        res[i] = val
      end
    end
  else
    bs:seek(start_offset)
    for i = 1, max_id do
      res[i] = bs:read_bool()
    end
  end
  return res
end

local function decode_vendor_range(bs, max_id, target_vendors)
  local num_entries = bs:read_int(12)
  local res = {}

  local target_map
  if target_vendors then
    target_map = {}
    for _, id in ipairs(target_vendors) do
      target_map[id] = true
    end
  end

  for _ = 1, num_entries do
    local is_range = bs:read_bool()
    local start_id = bs:read_int(16)
    if is_range then
      local end_id = bs:read_int(16)
      if target_map then
        for id = start_id, end_id do
          if target_map[id] then
            res[id] = true
          end
        end
      else
        for id = start_id, end_id do
          res[id] = true
        end
      end
    else
      if not target_map or target_map[start_id] then
        res[start_id] = true
      end
    end
  end

  return res
end

local function decode_vendor_section(self, start_offset)
  self.bs:seek(start_offset)
  local max_id = self.bs:read_int(16)
  if not max_id then
    return nil, start_offset
  end

  local is_range = self.bs:read_bool()
  local res
  if not is_range then
    res = decode_vendor_bitfield(
      self.bs,
      self.bs:pos(),
      max_id,
      self.options.targetVendors
    )
    return res, start_offset + 17 + max_id
  else
    res = decode_vendor_range(self.bs, max_id, self.options.targetVendors)
    return res, self.bs:pos()
  end
end

local function decode_publisher_restrictions(bs)
  local val = bs:read_int(12)
  if not val then
    return {}
  end
  local num_restrictions = val
  local res = {}

  for _ = 1, num_restrictions do
    local purpose_id = bs:read_int(6)
    local restriction_type = bs:read_int(2)
    local num_entries = bs:read_int(12)

    for _ = 1, num_entries do
      local is_range = bs:read_bool()
      local start_id = bs:read_int(16)
      local end_id = start_id
      if is_range then
        end_id = bs:read_int(16)
      end

      for vendor_id = start_id, end_id do
        if not res[vendor_id] then
          res[vendor_id] = {}
        end
        if not res[vendor_id][purpose_id] then
          res[vendor_id][purpose_id] = {}
        end
        res[vendor_id][purpose_id][restriction_type] = true
      end
    end
  end
  return res
end

local function decode_bitstream_field(self, bits, offset, is_bool)
  if offset then
    self.bs:seek(offset)
  end
  local val, err = self.bs:read_int(bits)
  if not val then
    if self.options.strict then
      return nil, err
    else
      table.insert(self.warnings, "bitstream error: " .. tostring(err))
      return nil
    end
  end
  if is_bool then
    return val == 1
  end
  return val
end

-- Lazy field definitions
local FIELDS = {
  version = function(self)
    return decode_bitstream_field(self, 6, OFFSETS.VERSION)
  end,
  cmpId = function(self)
    return decode_bitstream_field(self, 12, OFFSETS.CMP_ID)
  end,
  cmpVersion = function(self)
    return decode_bitstream_field(self, 12, OFFSETS.CMP_VERSION)
  end,
  consentScreen = function(self)
    return decode_bitstream_field(self, 6, OFFSETS.CONSENT_SCREEN)
  end,
  consentLanguage = function(self)
    self.bs:seek(OFFSETS.CONSENT_LANGUAGE)
    return decode_language(self.bs)
  end,
  vendorListVersion = function(self)
    return decode_bitstream_field(self, 12, OFFSETS.VENDOR_LIST_VERSION)
  end,
  policyVersion = function(self)
    return decode_bitstream_field(self, 6, OFFSETS.POLICY_VERSION)
  end,
  isServiceSpecific = function(self)
    return decode_bitstream_field(self, 1, OFFSETS.SERVICE_SPECIFIC, true)
  end,
  useNonStandardStacks = function(self)
    return decode_bitstream_field(
      self,
      1,
      OFFSETS.USE_NON_STANDARD_STACKS,
      true
    )
  end,
  purposeOneTreatment = function(self)
    return decode_bitstream_field(self, 1, OFFSETS.PURPOSE_ONE_TREATMENT, true)
  end,
  publisherCountryCode = function(self)
    self.bs:seek(OFFSETS.PUBLISHER_COUNTRY_CODE)
    return decode_language(self.bs)
  end,
  created = function(self)
    return decode_bitstream_field(self, 36, OFFSETS.CREATED)
  end,
  lastUpdated = function(self)
    return decode_bitstream_field(self, 36, OFFSETS.LAST_UPDATED)
  end,
  specialFeaturesOptIn = function(self)
    return decode_bitfield_fixed(self.bs, OFFSETS.SPECIAL_FEATURE_OPT_IN, 12)
  end,
  purposeConsents = function(self)
    return decode_bitfield_fixed(self.bs, OFFSETS.PURPOSE_CONSENT, 24)
  end,
  purposeLegitimateInterests = function(self)
    return decode_bitfield_fixed(self.bs, OFFSETS.PURPOSE_LI, 24)
  end,
  vendorConsents = function(self)
    local res, next_offset = decode_vendor_section(self, OFFSETS.VENDOR_CONSENT)
    self._cache.vendorLegitimateInterests_offset = next_offset
    return res
  end,
  vendorLegitimateInterests = function(self)
    local offset = self._cache.vendorLegitimateInterests_offset
    if not offset then
      local _ = self.vendorConsents
      offset = self._cache.vendorLegitimateInterests_offset
    end
    local res, next_offset = decode_vendor_section(self, offset)
    self._cache.publisherRestrictions_offset = next_offset
    return res
  end,
  publisherRestrictions = function(self)
    local offset = self._cache.publisherRestrictions_offset
    if not offset then
      local _ = self.vendorLegitimateInterests
      offset = self._cache.publisherRestrictions_offset
    end
    self.bs:seek(offset)
    local res = decode_publisher_restrictions(self.bs)
    self._cache.publisherTC_offset = self.bs:pos()
    return res
  end,
}

function Core.new(decoded_data, options)
  local self = setmetatable({
    bs = BitStream.new(decoded_data),
    options = options or {},
    _cache = {},
    warnings = {},
  }, {
    __index = function(tbl, key)
      if tbl._cache[key] ~= nil then
        return tbl._cache[key]
      end

      if FIELDS[key] then
        local val = FIELDS[key](tbl)
        tbl._cache[key] = val
        return val
      end

      return Core[key]
    end,
  })

  return self
end

function Core:to_table()
  local res = {}
  for key, _ in pairs(FIELDS) do
    res[key] = self[key]
  end
  res.tc_string = self.tc_string
  return res
end

return Core
