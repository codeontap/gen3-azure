[#ftl]

[#macro azure_lb_arm_deployment_generationcontract occurrence]
    [@addDefaultGenerationContract subsets=["template"] /]
[/#macro]

[#macro azure_lb_arm_deployment occurrence]
    [@debug message="Entering LB Setup" context=occurrence enabled=false /]

    [#local core = occurrence.Core]
    [#local solution = occurrence.Configuration.Solution]
    [#local resources = occurrence.State.Resources]

    [#local engine = solution.Engine]

    [#-- Network Resources --]
    [#local occurrenceNetwork = getOccurrenceNetwork(occurrence)]
    [#local networkLink = occurrenceNetwork.Link!{}]
    [#local networkLinkTarget = getLinkTarget(occurrence, networkLink)]
    [#if ! networkLinkTarget?has_content ]
        [@fatal message="Network could not be found" context=networkLink /]
        [#return]
    [/#if]
    [#local networkResources = networkLinkTarget.State.Resources]

    [#-- LB Resources --]
    [#local lb = resources["lb"]]
    [#local publicIP = resources["publicIP"]]
    [#local identity = resources["identity"]]
    [#local accessPolicy = resources["accessPolicy"]]
    [#local appGatewayDependencies = []]

    [#-- Instantiate LB Configs --]
    [#switch engine]
        [#case "application"]
            [#local gatewayIPConfigExists = false]
            [#local listenerPortsSeen = []]
            [#local frontendIPAddress = {}]
            [#local portProtocols = []]
            [#local gatewayIPConfigurations = []]
            [#local frontendIPConfigurations = []]
            [#local frontendPorts = []]
            [#local backendAddressPools = []]
            [#local backendHttpSettingsCollections = []]
            [#local httpListeners = []]
            [#local requestRoutingRules = []]
            [#local redirectConfigurations = []]
            [#local urlPathMaps = []]
            [#break]
    [/#switch]

    [#list occurrence.Occurrences![] as subOccurrence]

        [#local subCore = subOccurrence.Core]
        [#local subSolution = subOccurrence.Configuration.Solution]
        [#local subResources = subOccurrence.State.Resources]

        [#-- Port Resources --]
        [#local listener = subResources["listener"]]
        [#local frontendPort = subResources["frontendPort"]]
        [#local frontendIPConfiguration = subResources["frontendIPConfiguration"]]
        [#local gatewayIPConfiguration = subResources["gatewayIPConfiguration"]]
        [#local routingRule = subResources["routingRule"]]
        [#local backendSettingsCollection = subResources["backendSettingsCollection"]]
        [#local backendAddressPool = subResources["backendAddressPool"]]
        [#local urlPathMap = subResources["urlPathMap"]]
        [#local pathRule = subResources["pathRule"]]
        [#local redirectConfig = subResources["redirectConfiguration"]]
        [#local sslCert = subResources["sslCertificate"]]

        [#-- source and destination ports --]
        [#local mapping = solution.Mapping!subCore.SubComponent.Name]
        [#local source = (portMappings[mapping].Source)!""]
        [#local destination = (portMappings[mapping].Destination)!""]
        [#local sourcePort = (ports[source])!{}]
        [#local destinationPort = (ports[destination])!{}]

        [#local hasRedirect = isPresent(subSolution.Redirect)]
        [#local hasPathBasedRouting = (subSolution.Path == "default")]
        [#local hasRedirectQuery = (subSolution.Redirect.Query == "#\{query}")]

        [#if !(sourcePort?has_content && destinationPort?has_content)]
            [#continue]
        [/#if]
        [#local portProtocols += [ sourcePort.Protocol ]]
        [#local portProtocols += [ destinationPort.Protocol]]

        [#-- Certificate --]
        [#local certificateObject = getCertificateObject(
            subSolution.Certificate,
            segmentQualifiers,
            sourcePort.Id!source,
            sourcePort.Name!source
        )]
        [#local hostName = getHostName(certificateObject, subOccurrence)]
        [#local primaryDomainObject = getCertificatePrimaryDomain(certificateObject)]
        [#local fqdn = formatDomainName(hostName, primaryDomainObject)]

        [#-- Determine if this is the first mapping for the source port --]
        [#-- The assumption is that all mappings for a given port share --]
        [#-- the same listenerId, so the same port number shouldn't be  --]
        [#-- defined with different names                               --]
        [#local firstMappingForPort = !listenerPortsSeen?seq_contains(listener.Id)]
        [#switch engine]
            [#case "application"]
                [#if subSolution.Path != "default" ]
                    [#-- Only create the listener for default mappings      --]
                    [#-- The ordering of ports changes with their naming    --]
                    [#-- so it isn't sufficient to use the first occurrence --]
                    [#-- of a listener                                      --]
                    [#local firstMappingForPort = false]
                [/#if]
                [#break]
        [/#switch]
        [#if firstMappingForPort]
            [#local listenerPortsSeen += [listener.Id]]
            [#switch engine]
                [#case "application"]
                    [#-- Gateway Config Setup --]
                    [#-- We only want to apply the one Gateway IP Config --]
                    [#if !gatewayIPConfigExists]
                        [#local gatewayIPConfigurations += [
                            getAppGatewayIPConfiguration(
                                gatewayIPConfiguration.Name,
                                getSubnet(subCore.Tier, networkResources, true)
                            )
                        ]]
                        [#local gatewayIPConfigExists = true]
                    [/#if]
                    [#-- Frontend Setup --]
                    [#local sslCertificate = []]
                    [#if listener.Name == "https"]
                        [#-- User Assigned Identity is required for the    --]
                        [#-- App Gateway to request its Cert from KeyVault --]
                        [@createUserAssignedIdentity
                            id=identity.Id
                            name=identity.Name
                            location=regionId
                        /]
                        [#local appGatewayDependencies += [identity.Reference]]

                        [#-- KeyVault Cert's have a "Secret Identifier" that allows --]
                        [#-- their lookup without storing it manually as a secret.  --]
                        [#local sslCertificate = [getAppGatewaySslCertificate(
                            sslCert.Name,
                            getReference(AZURE_PROVIDER, {"Id": sslCert.Id, "Name": sslCert.Name}, AZURE_KEYVAULT_SECRET_RESOURCE_TYPE)
                        )]]
                    [/#if]

                    [#-- Only one IPv4 and one IPv6 IP Configuration can be applied --]
                    [#if !frontendIPAddress.Assigned!false]
                        [#if !hasRedirect]
                            [#local frontendIPConfigurations += [
                                getAppGatewayFrontendIPConfiguration(
                                    frontendIPConfiguration.Name,
                                    publicIP.Reference
                                )
                            ]]
                            [#local frontendIPAddress += {
                                "Configuration" : frontendIPConfiguration.SubReference,
                                "Assigned" : true
                            }]
                        [/#if]
                    [/#if]

                    [#local frontendPorts += [
                        getAppGatewayFrontendPort(frontendPort.Name, sourcePort.Port)
                    ]]
                    [#local httpListeners += [
                        getAppGatewayHttpListener(
                            listener.Name,
                            frontendIPAddress.Configuration,
                            frontendPort.SubReference,
                            sourcePort.Protocol,
                            hostName,
                            (listener.Name == "https")?then(sslCert.SubReference, "")
                        )
                    ]]

                    [#-- Routing Rule Setup --]
                    [#local requestRoutingRules += [
                        getAppGatewayRequestRoutingRule(
                            routingRule.Name,
                            hasPathBasedRouting?then("PathBasedRouting", "Basic"),
                            routingRule.Priority,
                            hasPathBasedRouting?then(
                                {},
                                hasRedirect?then(
                                    {},
                                    backendAddressPool.SubReference
                                )
                            ),
                            hasPathBasedRouting?then(
                                {},
                                hasRedirect?then(
                                    {},
                                    backendSettingsCollection.SubReference
                                )
                            ),
                            listener.SubReference,
                            urlPathMap.SubReference,
                            {},
                            hasRedirect?then(redirectConfig.SubReference, {})
                        )
                    ]]
                    [#break]
            [/#switch]
        [/#if]

        [#-- Configure Backend and Routing --]
        [#switch engine]

            [#case "application"]

                [#local rulePath = hasRedirect?then(subSolution.Redirect.Path, subSolution.Path)]

                [#if rulePath != "default"]
                    [#if rulePath?ends_with("/") && rulePath != "/" ]
                        [#local path = rulePath?ensure_ends_with("*")]
                    [#else]
                        [#-- Path includes "/#\{path}" --]
                        [#local path = rulePath?replace("/#\{path}", "/")?ensure_ends_with("*")]
                        [#local includePath = true]
                    [/#if]
                [#else]
                    [#local path = "/*"]
                [/#if]

                [#local pathRules = [
                    getAppGatewayPathRules(
                        pathRule.Name,
                        hasPathBasedRouting?then([path], []),
                        hasRedirect?then({}, backendAddressPool.SubReference),
                        hasRedirect?then({}, backendSettingsCollection.SubReference),
                        hasRedirect?then(redirectConfig.SubReference, {})
                    )
                ]]

                [#local urlPathMaps += [
                    getAppGatewayUrlPathMap(
                        urlPathMap.Name,
                        hasRedirect?then({}, backendAddressPool.SubReference),
                        hasRedirect?then({}, backendSettingsCollection.SubReference),
                        {},
                        hasRedirect?then(redirectConfig.SubReference, {}),
                        pathRules
                    )
                ]]

                [#-- Backend Setup --]
                [#-- LB Component is deliberately setup with empty backend pools. --]
                [#-- When the backend resource is created it will join the        --]
                [#-- backend pool.                                                --]
                [#if ! hasRedirect]
                    [#local backendAddresses = []]

                    [#local backendAddressPools += [
                        getAppGatewayBackendAddressPool(
                            backendAddressPool.Name,
                            backendAddresses
                        )
                    ]]
                    [#local backendHttpSettingsCollections += [
                        getAppGatewayBackendHttpSettingsCollection(
                            backendSettingsCollection.Name,
                            destinationPort.Port,
                            destinationPort.Protocol,
                            path,
                            false
                        )
                    ]]
                [/#if]

                [#-- Redirect Config --]
                [#if hasRedirect]

                    [#-- Find the Target Listener to redirect to --]
                    [#local redirectPortNumber = subSolution.Redirect.Port?number]
                    [#local foundListenerPorts = []]
                    [#list occurrence.Occurrences as sub]
                        [#local listener = sub.State.Resources["listener"]]
                        [#local listenerPortNumber = ports[listener.Name].Port]
                        [#local foundListenerPorts += [listenerPortNumber]]
                        [#if listenerPortNumber == redirectPortNumber]
                            [#local redirectTargetListener = listener.SubReference]
                        [/#if]
                    [/#list]

                    [#if ! redirectTargetListener?has_content]
                        [@fatal
                            message="Target Listener for Redirect does not exist."
                            context=
                                {
                                    "RedirectPortNumber" : redirectPortNumber,
                                    "FoundListenerPorts" : foundListenerPorts
                                }
                        /]
                    [/#if]

                    [#local redirectConfigurations += [
                        getAppGatewayRedirectConfiguration(
                            redirectConfig.Name,
                            subSolution.Redirect.Permanent,
                            redirectTargetListener,
                            "",
                            includePath!false,
                            hasRedirectQuery,
                            routingRule.SubReference,
                            urlPathMap.SubReference,
                            pathRule.SubReference
                        )
                    ]]
                [/#if]

                [#break]

        [/#switch]

    [/#list]

    [#-- Resource Creation --]
    [#switch engine]
        [#case "application"]

            [@createKeyVaultAccessPolicy
                id=accessPolicy.Id
                name=accessPolicy.Name
                vaultName=accessPolicy.KeyVault
                dependsOn=[identity.Reference]
                properties=
                    {
                        "accessPolicies" : [
                            getKeyVaultAccessPolicyObject(
                                formatAzureSubscriptionReference("tenantId"),
                                identity.PrincipalId,
                                getKeyVaultAccessPolicyPermissions(
                                    [],
                                    [
                                        "get",
                                        "list"
                                    ]
                                )
                            )
                        ]
                    }
            /]
            [#local appGatewayDependencies += [accessPolicy.Reference]]

            [@createPublicIPAddress
                id=publicIP.Id
                name=publicIP.Name
                location=regionId
                allocationMethod="Static"
            /]

            [#if sslCertificate?has_content]
                [#local identityObj =
                    {
                        "type" : "UserAssigned",
                        "userAssignedIdentities" : {
                            identity.Reference : {}
                        }
                    }
                ]
            [/#if]

            [@createApplicationGateway
                id=lb.Id
                name=lb.Name
                location=regionId
                skuName=lb.Sku
                skuTier=lb.Sku
                skuCapacity=1
                gatewayIPConfigurations=gatewayIPConfigurations
                frontendIPConfigurations=frontendIPConfigurations
                frontendPorts=frontendPorts
                backendAddressPools=backendAddressPools
                backendHttpSettingsCollection=backendHttpSettingsCollections
                httpListeners=httpListeners
                requestRoutingRules=requestRoutingRules
                redirectConfigurations=redirectConfigurations
                urlPathMaps=urlPathMaps
                sslCertificates=sslCertificate
                identity=identityObj!{}
                dependsOn=appGatewayDependencies
            /]
            [#break]

        [#default]
            [@fatal
                message="Unsupported engine type"
                context=
                    {
                        "LB" : lb.Name,
                        "Engine" : engine
                    }
            /]
            [#break]

    [/#switch]

[/#macro]
