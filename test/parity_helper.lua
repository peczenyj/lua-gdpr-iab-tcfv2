local M = {}

local function format_date(deciseconds)
    -- deciseconds is 1/10 of a second
    local seconds = math.floor(deciseconds / 10)
    -- We can use os.date for ISO-8601 but it's not perfectly compatible with all Lua versions
    -- without specific format strings.
    -- For testing purposes, we'll try to match the Perl project's output format.
    return os.date("!%Y-%m-%dT%H:%M:%SZ", seconds)
end

function M.map_to_perl_shape(parser_table)
    local p = parser_table
    local res = {
        version = p.version,
        created = format_date(p.created),
        last_updated = format_date(p.lastUpdated),
        cmp_id = p.cmpId,
        cmp_version = p.cmpVersion,
        consent_screen = p.consentScreen,
        consent_language = p.consentLanguage,
        vendor_list_version = p.vendorListVersion,
        policy_version = p.policyVersion,
        is_service_specific = p.isServiceSpecific,
        use_non_standard_stacks = p.useNonStandardStacks,
        purpose_one_treatment = p.purposeOneTreatment,
        publisher_country_code = p.publisherCountryCode,
        tc_string = p.tc_string,
        
        special_features_opt_in = p.specialFeaturesOptIn,
        purpose = {
            consents = p.purposeConsents,
            legitimate_interests = p.purposeLegitimateInterests,
        },
        vendor = {
            consents = p.vendorConsents,
            legitimate_interests = p.vendorLegitimateInterests,
        },
        -- publisher and other segments will be added in Phase 3/4
    }
    
    return res
end

return M
