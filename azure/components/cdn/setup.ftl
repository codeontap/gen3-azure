[#ftl]

[#macro azure_cdn_arm_deployment_generationcontract occurrence]
    [@addDefaultGenerationContract subsets=["template", "epilogue"] /]
[/#macro]

[#macro azure_cdn_arm_deployment occurrence]

    [@debug message="Entering CDN Component Setup" context=occurrence enabled=false /]

    [#local core = occurrence.Core]
    [#local resources = occurrence.State.Resources]
    [#local attributes = occurrence.State.Attributes]
    [#local solution = occurrence.Configuration.Solution]

    [#local wafPresent = isPresent(solution.WAF)]
    [#local frontDoor = resources["frontDoor"]]
    [#local wafPolicy = resources["wafPolicy"]]
    [#local frontendEndpointName = formatName(frontDoor.Name, "frontend")]
    [#local frontDoorLBSettingsName = formatName(frontDoor.Name, "lb", "settings")]
    [#local frontDoorFQDN = frontDoor.FrontDoorFQDN ]

    [#local securityProfile = getSecurityProfile(solution.Profiles.Security, CDN_COMPONENT_TYPE)]
    [#local wafRequired = (securityProfile.Enabled)!false ]

    [#-- Baseline lookup --]
    [#local baselineLinks = getBaselineLinks(occurrence, [ "OpsData" ], false, false)]
    [#local baselineComponentIds = getBaselineComponentIds(baselineLinks, "", "", "", "container")]
    [#local fragment = getOccurrenceFragmentBase(occurrence)]

    [#local routingRules = []]
    [#local backendPools = []]
    [#local frontendEndpoints = []]
    [#local healthProbeSettings = []]
    [#local httpReRouteRequired = false]
    [#local invalidationPaths = []]

    [#list occurrence.Occurrences![] as subOccurrence]

        [#local subCore = subOccurrence.Core]
        [#local subSolution = subOccurrence.Configuration.Solution]
        [#local subResources = subOccurrence.State.Resources]
        [#local subAttributes = subOccurrence.State.Attributes]
        [#local routingRuleResource = subResources["frontDoorRoute"]]
        [#local routingRulePathPattern = [routingRuleResource.PathPattern]]

        [#local healthProbeSettingsName = formatName(routingRuleResource.Name, "healthProbe")]

        [#local originLink = getLinkTarget(occurrence, subSolution.Origin.Link)]
        [#if !originLink?has_content]
            [#continue]
        [/#if]
        [#local originLinkTargetCore = originLink.Core]
        [#local originLinkTargetAttributes = originLink.State.Attributes]
        [#local originLinkTargetConfiguration = originLink.Configuration]

        [#switch originLinkTargetCore.Type]
            [#-- TODO(rossmurr4y):
                expand this to allow for S3, LB_PORT & APIGATEWAY component types. --]
            [#case SPA_COMPONENT_TYPE]

                [#local spaBaslineProfile = originLinkTargetConfiguration.Solution.Profiles.Baseline ]
                [#local spaBaselineLinks = getBaselineLinks(originLink, ["OpsData"], false, false)]
                [#local spaBaselineComponentIds = getBaselineComponentIds(spaBaselineLinks, "", "", "", "container")]
                [#local spaBaselineAttributes = spaBaselineLinks["OpsData"].State.Attributes]
                [#local storageAccount = spaBaselineAttributes["ACCOUNT_NAME"]]
                [#local spaBaselineResources = spaBaselineLinks["OpsData"].State.Resources]
                [#local operationsBlobContainer = spaBaselineResources["container"]]
                [#local webEndpoint = spaBaselineAttributes["WEB_ENDPOINT"]]
                [#local backendPoolName = formatName(core.Id, SPA_COMPONENT_TYPE)]

                [#-- Ports & Protocols --]
                [#local spaFrontEndPort = ports[originLinkTargetAttributes["BACKEND_PORT"]]]
                [#local acceptedProtocols=[spaFrontEndPort.Protocol?capitalize]]
                [#if spaFrontEndPort.Protocol == "HTTPS"]
                    [#local httpReRouteRequired = true]
                [/#if]

                [#-- SPA Config File Settings --]
                [#local configBlobContainer = originLinkTargetAttributes["CONFIG_STORAGE_CONTAINER"]]
                [#local forwardingPath = originLinkTargetAttributes["FORWARDING_PATH"]]
                [#local configFile = originLinkTargetAttributes["CONFIG_FILE"]]

                [#-- Establish the frontend endpoints --]
                [#local frontendEndpoints += [
                    getFrontDoorFrontendEndpoint(
                        frontendEndpointName,
                        frontDoorFQDN,
                        "Disabled",
                        "0",
                        wafRequired?then(wafPolicy.Reference, "")
                    )
                ]]

                [#-- health probe settings --]
                [#local healthProbeSettings += [
                    getFrontDoorHealthProbeSettings(
                        healthProbeSettingsName,
                        spaFrontEndPort.HealthCheck.Path,
                        spaFrontEndPort.Protocol?capitalize,
                        spaFrontEndPort.HealthCheck.Interval
                    )
                ]]

                [#-- Create backend pools--]
                [#local spaBackendPoolAddress =
                    webEndpoint?remove_beginning("https://")?remove_ending("/")]

                [#local spaBackendPool = [
                    getFrontDoorBackendPool(
                        backendPoolName,
                        [
                            getFrontDoorBackend(
                                spaBackendPoolAddress,
                                spaBackendPoolAddress,
                                "80",
                                "443"
                            )
                        ],
                        getSubResourceReference(
                            getChildReference(
                                frontDoor.Name, 
                                [
                                    getResourceObject(
                                        frontDoorLBSettingsName,
                                        "loadBalancingSettings"
                                    )
                                ]
                            )
                        ),
                        getSubResourceReference(
                            getChildReference(
                                frontDoor.Name,
                                [
                                    getResourceObject(
                                        healthProbeSettingsName,
                                        "healthProbeSettings"
                                    )
                                ]
                            )
                        )
                    )
                ]]
                [#local backendPools += spaBackendPool]

                [#-- Create routing rules --]
                [#local routingRules += [
                    getFrontDoorRoutingRule(
                        routingRuleResource.Name,
                        [
                            getSubResourceReference(
                                getChildReference(
                                    frontDoor.Name,
                                    [
                                        getResourceObject(
                                            frontendEndpointName,
                                            "frontendEndpoints"
                                        )
                                    ]
                                )
                            )
                        ],
                        acceptedProtocols,
                        routingRulePathPattern,
                        "#Microsoft.Azure.FrontDoor.Models.FrontdoorForwardingConfiguration",
                        spaFrontEndPort.Protocol?capitalize,
                        getChildReference(
                            frontDoor.Name,
                            [
                                getResourceObject(
                                    backendPoolName,
                                    "backendPools"
                                )
                            ]
                        ),
                        {},
                        forwardingPath
                    )
                ]]

                [@armResource
                    id=routingRuleResource.Id
                    name=routingRuleResource.Name
                    profile=routingRuleResource.Type
                /]

                [#break]
        [/#switch]

        [#-- Invalidate old content if applicable --]
        [#if subSolution.InvalidateOnUpdate]
            [#if ! invalidationPaths?seq_contains("/*") ]
                [#local invalidationPaths += [ routingRulePathPattern ]]
            [/#if]
        [/#if]

    [/#list]

    [#-- Parent occurrence --]
    [#if deploymentSubsetRequired(CDN_COMPONENT_TYPE, true)]

        [#-- Add HTTP redirect routing rule --]
        [#if httpReRouteRequired]
            [#local routingRules += [
                getFrontDoorRoutingRule(
                    "HttpToHttpsRedirect",
                    [
                        getSubResourceReference(
                            getChildReference(
                                frontDoor.Name,
                                [
                                    getResourceObject(
                                        frontendEndpointName,
                                        "frontendEndpoints"
                                    )
                                ]
                            )
                        )
                    ],
                    ["Http"],
                    ["/*"],
                    "#Microsoft.Azure.FrontDoor.Models.FrontdoorRedirectConfiguration"
                    "", "", "", "",
                    "Found",
                    "HttpsOnly"
                )
            ]]
        [/#if]

        [#-- Load Balancing Settings --]
        [#local loadBalancingSettings =
            [
                getFrontDoorLoadBalancingSettings(
                    frontDoorLBSettingsName
                )
            ]
        ]

        [@createFrontDoor
            id=frontDoor.Id
            name=frontDoor.Name
            location=regionId
            routingRules=routingRules
            loadBalancingSettings=loadBalancingSettings
            backendPools=backendPools
            frontendEndpoints=frontendEndpoints
            healthProbeSettings=healthProbeSettings
        /]


        [#if wafRequired ]
            [@createFrontDoorWAFPolicy
                id=wafPolicy.Id
                name=wafPolicy.Name
                location=regionId
                securityProfile=securityProfile

            /]
        [/#if]

    [/#if]

    [#-- Epilogue --]
    [#if deploymentSubsetRequired("epilogue", false)]
        [#-- If there is something to purge, and its previously been deployed, purge it --]
        [#if invalidationPaths?has_content && getReference(AZURE_PROVIDER, frontDoor.Id)?has_content]
            [@addToDefaultBashScriptOutput
                [
                    "case $\{DEPLOYMENT_OPERATION} in",
                    "  create|update)"
                    "    # Purge FrontDoor Endpoint",
                    "    info \"Purging frontDoor content ... \"",
                    "    az_purge_frontdoor_endpoint" +
                        " \"" + getReference(AZURE_PROVIDER, "ResourceGroup") + "\"" +
                        " \"" + frontDoor.Name + "\"" +
                        " \"" + asFlattenedArray(invalidationPaths, true)?join(' ') + "\" || return $?"
                        ";;",
                    "esac"
                ]
            /]
        [/#if]
    [/#if]

[/#macro]
