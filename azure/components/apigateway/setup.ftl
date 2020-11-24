[#ftl]

[#macro azure_apigateway_arm_deployment_generationcontract_application occurrence]
    [@addDefaultGenerationContract subsets=["pregeneration", "parameters", "template"] /]
[/#macro]

[#macro azure_apigateway_arm_deployment_application occurrence]
    [@debug message="Entering" context=occurrence enabled=false /]

    [#local core          = occurrence.Core]
    [#local solution      = occurrence.Configuration.Solution]
    [#local resources     = occurrence.State.Resources]
    [#local attributes    = occurrence.State.Attributes]
    [#local buildSettings = occurrence.Configuration.Settings.Build]
    [#local buildRegistry = buildSettings["BUILD_FORMATS"].Value[0]]

    [#-- resources --]
    [#local service           = resources["service"]]
    [#local identityproviders = resources["identityproviders"]]
    [#local product           = resources["product"]]
    [#local api               = resources["api"]]

    [#local sku = getSkuProfile(occurrence, core.Type)]

    [#-- Determine the stage variables required --]
    [#local stageVariables = {} ]
    [#local fragment = getOccurrenceFragmentBase(occurrence) ]

    [#-- Baselink Links --]
    [#local baselineLinks = getBaselineLinks(occurrence, ["SSHKey", "OpsData"], false, false)]
    [#local baselineAttributes = baselineLinks["SSHKey"].State.Attributes]
    [#local keyvault = baselineAttributes["KEYVAULT_ID"]]

    [#local contextLinks = getLinkTargets(occurrence)]
    [#assign _context =
        {
            "Id" : fragment,
            "Name" : fragment,
            "Instance" : core.Instance.Id,
            "Version" : core.Version.Id,
            "DefaultEnvironment" : defaultEnvironment(occurrence, contextLinks, baselineLinks),
            "Environment" : {},
            "Links" : contextLinks,
            "BaselineLinks" : baselineLinks,
            "DefaultCoreVariables" : false,
            "DefaultBaselineVariables" : false,
            "DefaultEnvironmentVariables" : false,
            "DefaultLinkVariables" : false,
            "Policy" : []
        }
    ]

    [#-- Add in fragment specifics including override of defaults --]
    [#if solution.Fragment?has_content ]
        [#local fragmentId = formatFragmentId(_context)]
        [#include fragmentList?ensure_starts_with("/")]
    [/#if]

    [#local stageVariables += getFinalEnvironment(occurrence, _context).Environment ]

    [#-- Links --]
    [#local lambdaAuthorizers = {}]
    [#local aadAppRegistrations = {}]

    [#list solution.Links?values?filter(l -> l?is_hash) as link]

        [#local linkTarget = getLinkTarget(occurrence, link, false)]
        [@debug message="Link Target" context=linkTarget enabled=false /]

        [#if !linkTarget?has_content]
            [#continue]
        [/#if]

        [#local linkTargetCore = linkTarget.Core]
        [#local linkTargetResources = linkTarget.State.Resources]

        [#switch linkTargetCore.Type]

            [#case LB_COMPONENT_TYPE]
                [#break]
            [#case LAMBDA_FUNCTION_COMPONENT_TYPE]
                [#local stageVariableName =
                        formatSettingName(
                            true,
                            link.Name,
                            linkTargetCore.SubComponent.Name,
                            "LAMBDA")
                ]
                [#local stageVariables +=
                    {
                        stageVariableName :
                            linkTargetResources["function"].Name
                    }
                ]
                [#if ["authorise", "authorize"]?seq_contains(linkTarget.Role) ]
                    [#local lambdaAuthorizers +=
                        {
                            link.Name : {
                                "Name" : link.Name,
                                "StageVariable" : stageVariableName,
                                "Default" : true
                            }
                        }
                    ]
                [/#if]
                [#break]
            [#case USERPOOL_COMPONENT_TYPE]
                [#if isLinkTargetActive(linkTarget)]
                    [#local aadAppRegistrations +=
                        {
                            link.Name : {
                                "Name" : link.Name,
                                "Reference" : link.Reference
                            }
                        }
                    ]
                [/#if]
                [#break]

        [/#switch]

    [/#list]

    [#-- Retrieve the OpenApi Spec from the registry --]
    [#-- and write it out to definition.json         --]
    [#if deploymentSubsetRequired("pregeneration", false)]
        [@addToDefaultBashScriptOutput
            content=
                getBuildScript(
                    "openapiFiles",
                    buildRegistry,
                    productName,
                    occurrence,
                    buildRegistry + ".zip"
                ) +
                [
                    "get_openapi_definition_file" + " " +
                            "\"" + buildRegistry + "\"" + " " +
                            "\"$\{openapiFiles[0]}\"" + " " +
                            "\"" + core.Id + "\"" + " " +
                            "\"" + core.Name + "\"" + " " +
                            "\"" + accountId + "\"" + " " +
                            "\"" + accountObject.ProviderId + "\"" + " " +
                            "\"" + regionId + "\"" + " || return $?",
                    "#"
                ]
        /]
    [/#if]

    [#-- Get the definition that was        --]
    [#-- created/updated in "pregeneration" --]
    [#if deploymentSubsetRequired("parameters", true) ]
        [#if ! definitionsObject[core.Id]??]
            [@fatal
                message="No API definition exists."
                context=definitionsObject
            /]
        [/#if]

        [#local openapiDefinition = (definitionsObject[core.Id])!{}]

        [#-- Open API Integrations --]
        [#local openapiIntegrations = getOccurrenceSettingValue(occurrence, [["apigw"], ["Integrations"]], true) ]
        [#if !(openapiIntegrations?has_content) || !(openapiIntegrations?is_hash)]
            [@fatal
                message="API Gateway integration definitions not found or is not a hash."
                context={"Integrations" : openapiIntegrations }
            /]
        [/#if]

        [#-- Open API Context --]
        [#local openapiContext =
            {
                "Account" : accountObject.ProviderId,
                "Region" : regionId,
                "AADAppRegistrations" : aadAppRegistrations,
                "LambdaAuthorizers" : lambdaAuthorizers,
                "FQDN" : attributes["FQDN"],
                "Scheme": attributes["SCHEME"],
                "BasePath": attributes["BASE_PATH"],
                "BuildReference" : (buildSettings["APP_REFERENCE"].Value)!buildSettings["BUILD_REFERENCE"].Value,
                "Name" : api.Name
            }
        ]

        [#-- API Management contact details. CMDB > openapi spec. --]
        [#if openapiDefinition.info?has_content]
            [#if openapiDefinition.info.contact?has_content]
                [#local service = mergeObjects(
                    service,
                    {
                        "ContactName" : openapiDefinition.info.contact.name!"",
                        "ContactEmail" : openapiDefinition.info.contact.email!""
                    }
                )]
            [/#if]
        [/#if]
        [#local service = mergeObjects(
            service,
            {} +
            attributeIfContent("ContactName", solution.azure\:Contact.Name!"") +
            attributeIfContent("ContactEmail", solution.azure\:Contact.Email!"")
        )]

        [#-- Extend Spec with extensions.                                        --]
        [#-- Azure only supports two openapi extensions, all others are skipped. --]
        [#-- Extensions: x-ms-paths & x-servers                                  --]
        [#local extendedDefinition =
            azExtendOpenapiDefinition(
                openapiDefinition,
                openapiIntegrations,
                openapiContext,
                true
            )]

        [#-- output inline spec as an ARM parameter. This puts the  --]
        [#-- spec in another file, keeping the template tidy and    --]
        [#-- allows us to easily call the ARM function "string()"   --]
        [#--  on it, to pass it inline to the API resource.         --]

        [@addParametersToDefaultJsonOutput
            id="openapi"
            parameter=extendedDefinition
        /]
        [@armParameter
            name="openapi"
            type="object"
        /]
    [/#if]

    [#if deploymentSubsetRequired(APIGATEWAY_COMPONENT_TYPE, true) ]
        [#list identityproviders?values as identityprovider]
            [@createApiManagementServiceIdentityProvider
                id=identityprovider.Id
                name=identityprovider.Name
                clientId=identityprovider.ObjectId
                keyvaultId=keyvault
                keyvaultSecret=identityprovider.SecretId
                dependsOn=[service.Reference]
            /]
        [/#list]

        [@createApiManagementServiceApi
            id=api.Id
            name=api.Name
            value=formatAzureStringFunction("", "parameters('openapi')")
            path=attributes["BASE_PATH"]
            dependsOn=[service.Reference]
        /]

        [@createApiManagementServiceProduct
            id=product.Id
            name=product.Name
            dependsOn=[api.Reference]
        /]

        [@createApiManagementService
            id=service.Id
            name=service.Name
            location=regionId
            skuName="Developer"
            publisherEmail=service.ContactEmail
            publisherName=service.ContactName
            identity=service.ManagedIdentity
        /]
    [/#if]

[/#macro]
