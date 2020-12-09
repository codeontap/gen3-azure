[#ftl]

[#macro azure_cdn_arm_state occurrence parent={} baseState={}]

    [#local core = occurrence.Core]
    [#local solution = occurrence.Configuration.Solution]

    [#local segmentSeedId = formatSegmentSeedId() ]
    [#local segmentSeed = getReference(AZURE_PROVIDER, segmentSeedId)]

    [#local frontDoorId = formatResourceId(AZURE_FRONTDOOR_RESOURCE_TYPE, core.Id)]
    [#local frontDoorName = formatAzureResourceName(
        core.FullName,
        AZURE_FRONTDOOR_RESOURCE_TYPE
    )]

    [#local wafPolicyId = formatDependentResourceId(AZURE_FRONTDOOR_WAF_POLICY_RESOURCE_TYPE, core.Id)]
    [#local wafPolicyName = formatAzureResourceName(
        formatName(AZURE_FRONTDOOR_WAF_POLICY_RESOURCE_TYPE, core.Tier, core.Component)
        getResourceType(frontDoorId)
    )]

    [#local frontDoorFqdn = formatDomainName(frontDoorName, 'azurefd.net')]

    [#if isPresent(solution.Certificate) ]
        [#local certificateObject = getCertificateObject(solution.Certificate, segmentQualifiers) ]
        [#local hostName = getHostName(certificateObject, occurrence) ]
        [#local primaryDomainObject = getCertificatePrimaryDomain(certificateObject) ]
        [#local fqdn = formatDomainName(hostName, primaryDomainObject)]
    [#else]
        [#local fqdn = getReference(AZURE_PROVIDER, frontDoorId)]
    [/#if]

    [#assign componentState =
        {
            "Resources" : {
                "frontDoor" : {
                    "Id" : frontDoorId,
                    "Name" : frontDoorName,
                    "FrontDoorFQDN" : frontDoorFqdn,
                    "Type" : AZURE_FRONTDOOR_RESOURCE_TYPE
                },
                "wafPolicy" : {
                    "Id" : wafPolicyId,
                    "Name" : wafPolicyName,
                    "Type" : AZURE_FRONTDOOR_WAF_POLICY_RESOURCE_TYPE,
                    "Reference" : getReference(AZURE_PROVIDER, {"Id": wafPolicyId, "Name": wafPolicyName})
                }
            },
            "Attributes" : {
                "FQDN" : fqdn,
                "URL" : "https://" + fqdn,
                "DISTRIBUTION_ID" : getReference(AZURE_PROVIDER, frontDoorId)
            },
            "Roles" : {
                "Inbound" : {},
                "Outbound" : {}
            }
        }
    ]
[/#macro]

[#macro azure_cdnroute_arm_state occurrence parent={} baseState={}]

    [#local core = occurrence.Core]
    [#local solution = occurrence.Configuration.Solution]

    [#local parentAttributes = parent.State.Attributes]
    [#local parentResources = parent.State.Resources]
    [#local frontDoorId = parentResources["frontDoor"].Id]
    [#local frontDoorRouteId =
        formatDependentResourceId(AZURE_FRONTDOOR_ROUTE_RESOURCE_TYPE, core.Id)]

    [#-- Set Default Path --]
    [#local pathPattern = solution.PathPattern]
    [#local isDefaultPath = false]
    [#switch pathPattern?lower_case]
        [#case ""]
        [#case "_default"]
        [#case "/"]
            [#local isDefaultPath = true]
            [#local pathPattern = "/*"]
    [/#switch]

    [#assign componentState =
        {
            "Resources" : {
                "frontDoorRoute" : {
                    "Id" : frontDoorRouteId,
                    "Name" : core.Name,
                    "Type" : AZURE_FRONTDOOR_ROUTE_RESOURCE_TYPE,
                    "PathPattern" : pathPattern,
                    "DefaultPath" : isDefaultPath
                }
            },
            "Attributes" : {
                "URL" : formatRelativePath(
                    parentAttributes["URL"],
                    pathPattern?remove_ending("*")
                )
            },
            "Roles" : {
                "Inbound" : {},
                "Outbound" : {}
            }
        }
    ]

[/#macro]
