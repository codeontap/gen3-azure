[#ftl]

[#-- Azure Resource Profiles --]
[#assign azureResourceProfiles = {}]
[#assign azureResourceProfilesConfiguration =
    {
        "Properties" : [
            {
                "Type" : "",
                "Value" : "Attributes of a Resource Profile."
            }
        ],
        "Attributes" : [
            {
                "Names" : "type",
                "Type" : STRING_TYPE,
                "Mandatory" : true
            },
            {
                "Names" : "apiVersion",
                "Type" : STRING_TYPE,
                "Mandatory" : true
            },
            {
                "Names" : "conditions",
                "Type" : ARRAY_OF_STRING_TYPE,
                "Default" : []
            },
            {
                "Names" : "max_name_length",
                "Type" : NUMBER_TYPE,
                "Mandatory" : false
            },
            {
                "Names" : "outputMappings",
                "Type" : OBJECT_TYPE,
                "Mandatory" : true
            },
            {
                "Names" : "global",
                "Type" : BOOLEAN_TYPE,
                "Default" : false
            },
            {
                "Names" : "scope",
                "Description" : "The default deployment scope for a given resource type. Defaults to the parent template.",
                "Type" : STRING_TYPE,
                "Values" : [ "subscription", "resourceGroup", "template", "pseudo" ],
                "Default" : "template"
            }
        ]
    }
]

[#macro addResourceProfile service resource profile={}]
    [@internalMergeResourceProfiles
        service=service
        resource=resource
        profile=profile
    /]

    [#-- Update outputMappings from profile
        Though outputMappings are now accessible from the profile, its important to use
        "outputMapping" variable to support cross-provider implementation.          --]
    [@addOutputMapping
        provider=AZURE_PROVIDER
        resourceType=resource
        mappings=profile.outputMappings
    /]
[/#macro]

[#-- Pseudo Resource Profiles are for resources that do not correspond --]
[#-- directly with an Azure ARM Resource type, but require an output.  --]
[#macro addPseudoResourceProfile service resource]
    [@addResourceProfile
        service=service
        resource=resource
        profile=
            {
                "apiVersion" : "pseudo",
                "type" : "pseudo",
                "outputMappings" : {
                    REFERENCE_ATTRIBUTE_TYPE: {
                        "Property" : "pseudo"
                    }
                }
            }
    /]
[/#macro]

[#-- formats an ARM Function --]
[#-- Usage --]
[#--    formatRawArmFunction("reference", [<resourceId>], "properties", "primaryEndpoints") --]
[#--    formatRawArmFunction("concat", ["quick", "brown", "fox"])                           --]
[#--    formatRawArmFunction("subscription", [], "id")                                      --]
[#-- Results                                                                                --]
[#--    "reference(<resourceId>).properties.primaryEndpoints"                               --]
[#--    "concat('quick', 'brown', 'fox')"                                                   --]
[#--    "subscription().id"                                                                 --]
[#function formatRawArmFunction function parts=[] args...]

    [#local stringifiedParts = []]
    [#list asFlattenedArray(parts) as part]
        [#if part?matches(r"(\w*)\(.*\)(\w||\.)*")]
            [#-- Regex pattern for a raw ARM function                --]
            [#-- "function(<part>, <part>).<potential-attributes>"   --]
            [#-- Do not string-ify them or they will not interpolate --]
            [#local stringifiedParts += [part]]
        [#else]
            [#local stringifiedParts += [r"'" + part + r"'"]]
        [/#if]
    [/#list]
    [#local parameters = stringifiedParts?has_content?then( concatenate(asFlattenedArray(stringifiedParts), r", "), "")]
    [#local attributes = args?has_content?then(concatenate(asFlattenedArray(["."] + args), "."), "")]
    [#return function + "(" + parameters + ")" + attributes]
[/#function]

[#function formatArmFunction function parts=[] args...]
    [#return "[" + formatRawArmFunction(function, parts, args) + "]" ]
[/#function]

[#-- ARM Function Dependencies                                      --]
[#-- ARM allows the referencing of a resource through two functions --]
[#-- "reference"                                                    --]
[#--    + returns the resource as an object                         --]
[#--    + only valid on resource properties or in outputs           --]
[#--    + can be accessed via name or resource identifier           --]
[#--    - cannot be used to establish dependencies                  --]
[#-- "resourceId"                                                   --]
[#--    + returns the resource identifier as a string               --]
[#--    + can be used everywhere                                    --]
[#--    - the required arguments change based on scope              --]
[#--    - cannot be used to retrieve resource attributes            --]
[#-- getReference combines both as necessary to construct any       --]
[#-- particular combination of reference requirements               --]
[#function azure_getReference id name="" attributeType=""]

    [#if id?is_hash
        && id?keys?seq_contains("Id")
        && id?keys?seq_contains("Name")]
        [#local name = id.Name]
        [#local id = id.Id]
    [/#if]

    [#if ! isPartOfCurrentDeploymentUnit(id)]
        [#return getExistingReference(AZURE_PROVIDER, id, attributeType)]
    [/#if]
    
    [#-- Reference Properties --]
    [#local resourceType = getResourceType(id)]
    [#if resourceType?has_content]
        [#local profile = getAzureResourceProfile(resourceType)]
    [/#if]
    [#if ! ((profile!{})?has_content)]
        [@fatal
            message="Could not find the resource type."
            context={"Id" : id, "Profiles" : azureResourceProfiles}
        /]
        [#return ""]
    [/#if]

    [#-- To access the properties of a resource in the same scope              --]
    [#-- it is necessary to wrap a "resourceId" function in a                  --]
    [#-- "reference" function.                                                 --]
    [#-- Example: "[reference(resourceId(<type>, <name>), 'Full').properties]" --]
    [#if attributeType?has_content && resourceType?has_content]
        [#local nameSegments = getAzureResourcePropertySegments(name)]
        [#local resourceId = formatRawArmFunction("resourceId", [profile.type, nameSegments])]
        [#local propertyPath = getOutputMappings(AZURE_PROVIDER, resourceType, attributeType).Property!""]
        [#if propertyPath?has_content]
            [#local args = propertyPath?split(".")]
        [/#if]
        [#local functionType = "reference"]
        [#local parts = [resourceId, profile.apiVersion, 'Full']]

    [#elseif attributeType?has_content]
        [#-- "reference" function required --]
        [#local propertyPath = getOutputMappings(AZURE_PROVIDER, resourceType, attributeType).Property!""]
        [#if propertyPath?has_content]
            [#local args = propertyPath?split(".")]
        [/#if]
        [#local functionType = "reference"]
        [#local parts = [id, profile.apiVersion, 'Full']]

    [#else]
        [#-- "resourceId" function required --]
        [#local functionType = "resourceId"]
        [#local nameSegments = getAzureResourcePropertySegments(name)]
        [#local parts = [profile.type, nameSegments]]
        [#local args = []]

    [/#if]

    [#return formatArmFunction(functionType, parts, args)]
[/#function]

[#function getChildReference parentName children]
    [#return 
        formatArmFunction(
            "concat",
            [
                formatRawArmFunction("reference", [parentName, 'Full'], "id"),
                children?map(c -> formatPath(true, c.Type, c.Name))
            ]
        )
    ]
[/#function]

[#function constructResourceId subscription resourceGroup provider resource parents=[]]
    [#if ! resource?is_hash]
        [@fatal
            message="Cannot construct resourceId with provided resource. Resource must be a hash, with Name and Type attributes."
            context={
                "Subscription" : subscription,
                "ResourceGroup" : resourceGroup,
                "Provider" : provider,
                "Resource" : resource,
                "Parents" : parents![]
            }
        /]
    [/#if]
    [#local parts = [
        "subscriptions",
        subscription,
        "resourceGroups",
        resourceGroup,
        "providers",
        provider,
        resource.Type,
        resource.Name ]]
    [#return formatPath(true, parts)]
[/#function]

[#function getResourceObject name type index=0]
    [#return {
        "Index" : index,
        "Name" : name,
        "Type" : type }]
[/#function]

[#function getParameterReference parameterName boilerplate=true]
    [#return
        boilerplate?then(
            "[parameters('" + parameterName + "')]",
            "parameters('" + parameterName + "')"
        )
    ]
[/#function]

[#-- turn a list of resource Id's into an array of objects with a key of "id". --]
[#-- i.e [{"id": "<resource 1 reference>"}, {"id", "<resource 2 reference>"}] --]
[#-- this is a common way for one azure resource to reference another sub-resource --]
[#function getSubResourceReference id]
    [#return {"id": id}]
[/#function]
[#function getSubResourceReferences ids...]
    [#local results = {}]
    [#list ids as id]
        [#local results += getSubResourceReference(id)]
    [/#list]
    [#return results]
[/#function]

[#--Formats a reference to a subscription's attributes:
id, subscriptionId, tenantId or displayName --]
[#function formatAzureSubscriptionReference attribute=""]
 [#return
    "[subscription()" + (attribute?has_content)?then(attribute?ensure_starts_with("."), "") + "]"
 ]
[/#function]

[#--Formats a reference to a resourceGroups attributes:
id, name, type, location, managedBy, tags, properties.provisioningState --]
[#function formatAzureResourceGroupReference attribute=""]
 [#return
    "[resourceGroup()" + (attribute?has_content)?then(attribute?ensure_starts_with("."), "") + "]"
 ]
[/#function]

[#--
    Azure has strict rules around resource name "segments" (parts seperated by a '/').
    The rules that must be adhered to are:
        - A root level resource must have one less segment in the name than the
            resource type (typically just the 1 segment).
        - Child resources must have the same number of segments as the child type.
            (this is typically 1 for the child, and 1 per parent resource.)
--]
[#function formatAzureResourceName name profile primaryParent=""]

    [#local name = name?split(":")?last]
    [#local resourceProfile = getAzureResourceProfile(profile)]
    [#local conditions = resourceProfile.conditions]
    [#local conditions += ["segment_out_names"]]
    [#list conditions as condition]
        [#switch condition]
            [#case "alphanumeric_only"]
                [#local name = replaceAlphaNumericOnly(name, "")]
                [#break]
            [#case "alphanumerichyphens_only"]
                [#local name = name?replace("[^a-zA-Z\\d-]", "", "r" ) ]
                [#break]
            [#case "globally_unique"]
                [#local segmentSeed = getStackOutput(AZURE_PROVIDER, formatSegmentResourceId("seed"))]
                [#local name = formatName(name, segmentSeed)]
                [#break]
            [#case "max_length"]
                [#local name = name?truncate_c(resourceProfile.max_name_length, '')]
                [#break]
            [#case "name_to_lower"]
                [#local name = name?lower_case]
                [#break]
            [#case "parent_to_lower"]
                [#local primaryParent = primaryParent?lower_case ]
                [#break]
            [#case "segment_out_names"]
                [#-- This will always happen last --]
                [#local name = formatRelativePath( (primaryParent!""), name?remove_ending("-"))]
                [#break]
            [#default]
                [@fatal
                    message="Error formatting Resource Id Reference: Azure Resource Profile Condition does not exist."
                    context=condition
                /]
                [#break]
        [/#switch]
    [/#list]

    [#return name]

[/#function]

[#function getAzureResourcePropertySegments property]
    [#return property?split("/")]
[/#function]

[#function getAzureResourceProfile resourceType serviceType=""]

    [#-- Service has been provided, so lookup can be specific --]
    [#if serviceType?has_content]
        [#list azureResourceProfiles[serviceType] as resource, attr]
            [#if resource == resourceType]
                [#local profileObj = azureResourceProfiles[serviceType][resource]]
            [/#if]
        [/#list]
    [#else]
        [#-- Service has not been specific, check all Services for the resourceType --]
        [#list azureResourceProfiles as service, resources]
            [#list resources as resource, attr]
                [#if resource = resourceType]
                    [#local profileObj = attr]
                [/#if]
            [/#list]
        [/#list]
    [/#if]

    [#if profileObj?has_content]
        [#return profileObj]
    [#else]
        [@fatal 
            message="Resource Profile not found"
            context={
                "ServiceType" : serviceType,
                "ResourceType" : resourceType,
                "apiVersion" : "HamletFatal: ResourceProfile not found.",
                "conditions" : [],
                "type" : "Hamlet/UnknownType"
            }
        /]
        [#return {}]
    [/#if]
[/#function]

[#-- Formats a call to the Azure ARM "concat" function. --]
[#function formatAzureConcatFunction segments...]
    [#local parts = asArray(segments)?join("', '")]
    [#return "[concat('" + parts + "')]"]
[/#function]

[#-- Formats a call to the Azure Arm "string() function     --]
[#-- output the params as ARM parameters. This puts the     --]
[#-- params in another file, keeping the template tidy and  --]
[#-- allows us to easily call the ARM function "string()"   --]
[#-- on them, to pass them inline as necessary.             --]
[#-- This is particularly helpful when the string is huge.  --]
[#function formatAzureStringFunction stringFormat="" parameters...]
    [#local args = stringFormat?has_content?then([stringFormat, parameters], [parameters])]
    [#return "[string(" + asFlattenedArray(args)?join("', '") + ")]"]
[/#function]

[#--
    Azure has some default tags to reference standard IP ranges.
    We use that here as Azure does not accept 0.0.0.0/0 as reference to Internet.
--]
[#function formatAzureIPAddress ip]
    [#local result = ""]
    [#if ip?has_content]
        [#local result = ip?replace("0.0.0.0/0", "Internet")]
    [/#if]
    [#return result]
[/#function]

[#function formatAzureIPAddresses ipAddresses...]
    [#local result = []]
    [#list ipAddresses as ip]
        [#if ip?has_content]
            [#local result += [formatAzureIPAddress(ip)]]
        [/#if]
    [/#list]
    [#return result]
[/#function]

[#function getAzServiceEndpoint serviceName serviceType resourceName extensions...]

    [#local endpoints = {}]
    [#switch serviceName]
        [#case "Microsoft.ContainerRegistry"]
            [#local endpoints =
                {
                    "containerRegistry" : "azurecr.io"
                }
            ]
            [#break]
        [#case "Microsoft.KeyVault"]
            [#local endpoints =
                {
                    "vault" : "vault.azure.net/"
                }
            ]
            [#break]
        [#case "Microsoft.Storage"]
            [#local endpoints =
                {
                    "blob"  : "blob.core.windows.net/",
                    "dfs"   : "dfs.core.windows.net/",
                    "file"  : "file.core.windows.net/",
                    "queue" : "queue.core.windows.net/",
                    "table" : "table.core.windows.net/",
                    "web"   : "web.core.windows.net/"
                }
            ]
        [#default]
            [@fatal
                message="Unsupported Azure Endpoint Service specified."
                context=
                    {
                        "serviceName" : serviceName,
                        "serviceType" : serviceType,
                        "resourceName" : resourceName,
                        "extensions" : extensions
                    }
            /]
    [/#switch]

    [#local endpoint =
        "https://" +
        resourceName +
        extensions?join(".")?ensure_starts_with(".")?ensure_ends_with(".") +
        endpoints[serviceType]
    ]

    [#return endpoint]

[/#function]
[#-------------------------------------------------------
-- Internal support functions for resource processing --
---------------------------------------------------------]

[#macro internalMergeResourceProfiles service resource profile]
    [#if profile?has_content ]
        [#assign azureResourceProfiles =
            mergeObjects(
                azureResourceProfiles,
                {
                    service : {
                        resource : getCompositeObject(
                            azureResourceProfilesConfiguration.Attributes,
                            profile
                        )
                    }
                }
            )
        ]
    [/#if]
[/#macro]

[#-- Function for determining if a Managed Identity is required. --]
[#function getAzureManagedIdentity linkTarget]
    [#return (linkTarget.Role)?has_content?then({ "type" : "SystemAssigned" },{})]
[/#function]

[#-- Services that must always be available to the provider --]
[@includeServicesConfiguration
    provider=AZURE_PROVIDER
    deploymentFramework=AZURE_RESOURCE_MANAGER_DEPLOYMENT_FRAMEWORK
    services=[
        AZURE_RESOURCES_SERVICE
    ]
/]
