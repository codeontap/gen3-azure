[#ftl]

[#macro azure_apigateway_arm_state occurrence parent={}]

    [#local core = occurrence.Core]
    [#local solution = occurrence.Configuration.Solution]

    [#-- Process Resource Naming Conditions --]
    [#local serviceId = formatResourceId(AZURE_API_MANAGEMENT_SERVICE, core.FullName)]
    [#local serviceName = formatAzureResourceName(
        core.FullName,
        AZURE_API_MANAGEMENT_SERVICE
    )]

    [#local productId = formatResourceId(AZURE_API_MANAGEMENT_SERVICE_PRODUCT, core.ShortName)]
    [#local productName = formatAzureResourceName(
        formatName(AZURE_API_MANAGEMENT_SERVICE_PRODUCT, core.ShortName),
        AZURE_API_MANAGEMENT_SERVICE_PRODUCT,
        serviceName
    )]

    [#local apiId = formatResourceId(AZURE_API_MANAGEMENT_SERVICE_API, core.ShortName)]
    [#local apiName = formatAzureResourceName(
        formatName(AZURE_API_MANAGEMENT_SERVICE_API, core.ShortName),
        AZURE_API_MANAGEMENT_SERVICE_API,
        serviceName
    )]

    [#local certificatePresent = isPresent(solution.Certificate)]
    [#local mappingPresent = isPresent(solution.Mapping)]
    [#local publishPresent = isPresent(solution.Publish)]

    [#local endpointType       = solution.EndpointType]
    [#local isEdgeEndpointType = solution.EndpointType == "EDGE"]

    [#local stageName = valueIfContent(
                            core.Version.Name,
                            core.Version.Name,
                            valueIfContent(
                                core.Instance.Name,
                                core.Instance.Name,
                                core.Name
                            ))]

    [#local internalFqdn =
        formatDomainName(
            serviceName,
            "azure-api.net"
        )
    ]

    [#local fqdn = internalFqdn]
    [#local stagePath = stageName]

    [#-- Effective API Gateway end points --]
    [#local hostName = "" ]

    [#-- Custom domain definitions needed for signing --]

    [#local customHostName = "" ]

    [#if certificatePresent]
        [#local certificateObject = getCertificateObject(solution.Certificate!"", segmentQualifiers)]
        [#local certificateDomains = getCertificateDomains(certificateObject) ]
        [#local primaryDomainObject = getCertificatePrimaryDomain(certificateObject) ]
        [#local hostName = getHostName(certificateObject, occurrence) ]
        [#local docsHostName = hostName ]

        [#if mappingPresent]
            [#local fqdn = formatDomainName(hostName, primaryDomainObject)]
            [#if !(solution.Mapping.IncludeStage)]
                [#local stagePath = ""]
            [/#if]
        [#else]
            [#local fqdn = formatDomainName(hostName, primaryDomainObject)]
        [/#if]
    [/#if]

    [#-- Link Processing--]
    [#local apimManagedIdentity = {}]
    [#local identityProviders = {}]
    [#list solution.Links?values?filter(l -> l?is_hash) as link]

        [#local linkTarget = getLinkTarget(occurrence, link, false)]

        [#if !linkTarget?has_content]
            [#continue]
        [/#if]

        [#local apimManagedIdentity = mergeObjects(
            apimManagedIdentity,
            getAzureManagedIdentity(linkTarget)
        )]

        [#local linkTargetCore = linkTarget.Core]
        [#switch linkTargetCore.Type]

            [#case USERPOOL_COMPONENT_TYPE]
                [#list linkTarget.Occurrences as subOccurrence]

                    [#local subCore = subOccurrence.Core]
                    [#local subAttributes = subOccurrence.State.Attributes]
                    [#local authProviders = subAttributes["AuthProviders"]![]]

                    [#switch subCore.Type]

                        [#case USERPOOL_CLIENT_COMPONENT_TYPE]
                            [#list authProviders as identityProvider]

                                [#local identityproviderId = formatResourceId(AZURE_API_MANAGEMENT_SERVICE_IDENTITY_PROVIDER, identityProvider)]
                                [#local identityproviderName = formatAzureResourceName(
                                    identityProvider,
                                    AZURE_API_MANAGEMENT_SERVICE_IDENTITY_PROVIDER,
                                    serviceName
                                )]
                                [#local identityProviderSecretId = formatSecretName(
                                    subCore.ShortName
                                )]

                                [#if isLinkTargetActive(subOccurrence)]
                                    [#local identityProviders +=
                                        {
                                            subCore.Id : {
                                                "Id" : identityproviderId,
                                                "Name" : identityproviderName,
                                                "Type" : AZURE_API_MANAGEMENT_SERVICE_IDENTITY_PROVIDER,
                                                "Reference" : getReference(AZURE_PROVIDER, {"Id": identityproviderId, "Name": identityproviderName}),
                                                "ObjectId" : subAttributes["CLIENT_OBJECT_ID"]!getReference(AZURE_PROVIDER, subCore.Id),
                                                "SecretId" : identityProviderSecretId
                                            }
                                        }
                                    ]
                                [/#if]

                            [/#list]
                            [#break]

                    [/#switch]

                [/#list]
                [#break]

        [/#switch]
    [/#list]

    [#switch solution.BasePathBehaviour!"ignore"]
        [#case "ignore"]
            [#local basePath = ""]
            [#break]
        [#case "prepend"]
            [#local basePath = stagePath]
            [#break]
        [#case "split"]
        [#default]
            [@fatal
                message="Unsupported BasePathValue."
                context={ "BasePathBehaviour" : solution.BasePathBehaviour }
                detail="The Azure provider only supports \"ignore\" and \"prepend\" values."
            /]
            [#break]
    [/#switch]

    [#assign componentState =
        {
            "Resources" : {
                "service" : {
                    "Id": serviceId,
                    "Name" : serviceName,
                    "ManagedIdentity" : apimManagedIdentity,
                    "Type" : AZURE_API_MANAGEMENT_SERVICE,
                    "Reference" : getReference(AZURE_PROVIDER, {"Id": serviceId, "Name": serviceName})
                },
                "identityproviders" : identityProviders,
                "product" : {
                    "Id": productId,
                    "Name" : productName,
                    "Type" : AZURE_API_MANAGEMENT_SERVICE_PRODUCT,
                    "Reference" : getReference(AZURE_PROVIDER, {"Id": productId, "Name": productName})
                },
                "api" : {
                    "Id" : apiId,
                    "Name" : apiName,
                    "Type" : AZURE_API_MANAGEMENT_SERVICE_API,
                    "Reference" : getReference(AZURE_PROVIDER, {"Id": apiId, "Name": apiName})
                }
            },
            "Attributes" : {
                "FQDN" : fqdn,
                "SCHEME": "https",
                "BASE_PATH": basePath
            },
            "Roles" : {
                "Inbound" : {},
                "Outbound" : {}
            }
        }
    ]

[/#macro]
