[#ftl]

[#function getArmTemplateDefaultOutputs]
    [#return
        {
            REFERENCE_ATTRIBUTE_TYPE : {
                "Attribute" : "id"
            }
        }
    ]
[/#function]

[#function getArmTemplateCoreOutputs
    region=formatAzureResourceGroupReference("location")
    account=formatAzureSubscriptionReference("id")
    resourceGroup=formatAzureResourceGroupReference("name")
    deploymentUnit=getDeploymentUnit()
    deploymentMode=commandLineOptions.Deployment.Mode]

    [#return {
        "Subscription": { "type": "string", "value": account },
        "ResourceGroup": { "type": "string", "value": resourceGroup },
        "Region": { "type": "string", "value": region },
        "DeploymentUnit": {
            "type": "string",
            "value":
                deploymentUnit +
                (
                    (!(ignoreDeploymentUnitSubsetInOutputs!false)) &&
                    (deploymentUnitSubset?has_content)
                )?then(
                    "-" + deploymentUnitSubset?lower_case,
                    ""
                )
        },
        "DeploymentMode" : { "type": "string", "value" : deploymentMode }
    }]
[/#function]

[#function getArmOutput name type value condition=""]
    [#return {
        name : {
            "type" : type,
            "value" : value
        } +
        attributeIfContent("condition", condition)
    }]
[/#function]

[#-- Uses a resources' output mappings with the provided scope to          --]
[#-- construct an "outputs" object. Resources that are nested inside a     --]
[#-- "Deployment" resource (any resource with a scope of "resourceGroup" or--]
[#-- "subscription") will also have their outputs nested. In order to      --]
[#-- have them output alongside non-nested resource outputs, outputs at the--]
[#-- "template" scope must be structured to point to the values of the     --]
[#-- nested resource output values.                                        --]
[#function constructArmOutputsFromMappings id name scope mappings=[]]
    [#local result = {}]
    [#switch scope]
        [#case "subscription"]
        [#case "resourceGroup"]

            [#-- redirect values to nested resource outputs --]
            [#list mappings as attributeType,attributes]
                [#list attributes as attributeName,attributeValue]

                    [#if attributeType == REFERENCE_ATTRIBUTE_TYPE || attributeValue == REFERENCE_ATTRIBUTE_TYPE]
                        [#local outputId = id]
                    [#else]
                        [#local outputId = formatAttributeId(id, attributeType)]
                    [/#if]

                    [#local dataType = getOutputMappingDataType(attributeType)]
                    [#local value = formatArmFunction("reference", [name], "outputs", outputId, "value")]
                    [#local result += getArmOutput(outputId, dataType, value)]
                [/#list]
            [/#list]
            [#break]

        [#case "template"]
            [#list mappings as attributeType,attributes]
                [#local dataType = getOutputMappingDataType(attributeType)]
                [#list attributes as attributeName,attributeValue]
                    [#if attributeType == REFERENCE_ATTRIBUTE_TYPE || attributeValue == REFERENCE_ATTRIBUTE_TYPE]
                        [#local outputName = id]
                        [#local value = getReference(AZURE_PROVIDER, {"Id": id, "Name": name})]
                    [#elseif attributeType == NAME_ATTRIBUTE_TYPE || attributeValue == NAME_ATTRIBUTE_TYPE]
                        [#local outputName = formatId(id, NAME_ATTRIBUTE_TYPE)]
                        [#local value = name]
                    [#else]
                        [#local outputName = formatAttributeId(id, attributeType)]
                        [#local value = getReference(AZURE_PROVIDER, {"Id": id, "Name": name}, attributeType)]
                    [/#if]
                    [#local result += getArmOutput(outputName, dataType, value)]
                [/#list]
            [/#list]
            [#break]

        [#-- Pseudo resources simply output their name so they can be verified as deployed --]
        [#case "pseudo"]
            [#return getArmOutput(name, "string", "pseudo")]
            [#break]

    [/#switch]
    [#return result]
[/#function]

[#macro addParametersToDefaultJsonOutput id parameter]
   [@addToDefaultJsonOutput
        content=
            {
                "$schema": ARMSchemas.Parameters,
                "contentVersion": "1.0.0.0",
                "parameters" : {
                    id : {
                      "value" : parameter
                    }
                }
            }
    /]
[/#macro]

[#macro addReferenceParameterToDefaultJsonOutput id vaultId referenceName]

    [@addToDefaultJsonOutput
        content=
            {
                "$schema": ARMSchemas.Parameters,
                "contentVersion": "1.0.0.0",
                "parameters" : {
                    id : getKeyVaultParameter(vaultId, referenceName)
                }
            }
    /]
[/#macro]

[#function pseudoArmStackOutputScript description outputs filesuffix=""]
    [#local outputString = ""]

    [#list getArmTemplateCoreOutputs(region, accountObject.ProviderId, commandLineOptions.Deployment.ResourceGroup.Name) as key,value]
        [#if value?is_hash]
            [#local outputs += { key, value.value }]
        [#else]
            [#local outputs += { key, value }]
        [/#if]
    [/#list]

    [#list outputs as key,value]
        [#local outputString +=
          "\"" + key + "\" \"" + value + "\" "
        ]
    [/#list]

    [#return
        [
            "create_pseudo_stack" + " " +
            "\"" + description + "\"" + " " +
            "\"$\{CF_DIR}/$(fileBase \"$\{BASH_SOURCE}\")" + (filesuffix?has_content)?then("-" + filesuffix, "") + "-pseudo-stack.json\" " +
            outputString + " || return $?"
        ]
    ]

[/#function]

[#macro armParameter name type="securestring" default=""]
    [@mergeWithJsonOutput
        name="parameters"
        content=
            {
                name : {
                    "type": type
                } +
                attributeIfContent("defaultValue", default)
            }
    /]
[/#macro]

[#macro armVariable name value]
    [@mergeWithJsonOutput
        name="variables"
        content={ name : value }
    /]
[/#macro]

[#function getOutputMappingDataType type]
    [#switch type]
        [#case DICTIONARY_ATTRIBUTE_TYPE]
            [#return "object"]
            [#break]

        [#default]
            [#return "string"]
            [#break]
    [/#switch]
[/#function]

[#-- Deconstruct a resourceId value into discovered scopes --]
[#function getResourceScopeFromResourcePath id]
    [#local segments = getAzureResourcePropertySegments(id)]
    [#local subscriptionIndex = segments?seq_index_of("subscriptions")!""]
    [#local resourceGroupIndex = segments?seq_index_of("resourceGroups")!""]
    [#local providerIndex = segments?seq_index_of("providers")!""]
    [#local resourceIndex = segments?size - 2]
    [#local resourceSegments = segments?filter(s -> segments?seq_index_of(s) >= resourceIndex)]
    [#local parentSegments = segments?filter(s -> segments?seq_index_of(s) > (providerIndex + 1) && segments?seq_index_of(s) < resourceIndex)![]]
    [#local end = segments?size - 1]
    [#local parents = []]

    [#-- Validation --]
    [#local required = [ subscriptionIndex, resourceGroupIndex, providerIndex, resourceSegments]]
    [#local minSegmentLength = 8]
    [#local validScope = true]
    [#if segments?size < minSegmentLength]
        [@fatal
            message="Resource Path is too short to determine scope."
            context={ "Path" : id }
        /]
        [#local validScope = false]
    [/#if]
    [#list required as segment]

        [#-- valid segments will be int or array --]
        [#if segment?is_string]
            [@fatal
                messaage="ResourceId missing mandatory segments."
                context={
                    "SubscriptionPresent" : subscriptionIndex?has_content,
                    "ResourceGroupPresent" : resourceGroupIndex?has_content,
                    "ProviderPresent" : providerIndex?has_content,
                    "ResourcePresent" : resourceSegments?has_content
                }
            /]
            [#local validScope = false]
        [/#if]
    [/#list]

    [#-- Segments remaining in an Id after the provider value are parents --]
    [#if parentSegments?has_content]
        [#list parentSegments as segment]
            [#if segment?item_parity == "odd" && segment?has_next]
                [#local segmentIndex = parentSegments?seq_index_of(segment)]
                [#local parents += [
                    {
                        "Index" : segment?counter,
                        "Name" : parentSegments[segmentIndex + 1],
                        "Type" : parentSegments[segmentIndex]
                    }
                ]]
            [/#if]
        [/#list]
    [/#if]
    [#if validScope]
        [#return
            {
                "Resource" : {
                    "Name" : segments?sequence[resourceIndex + 1],
                    "Type" : segments?sequence[resourceIndex]
                }
            } +
            attributeIfContent("Subscription", segments?sequence[subscriptionIndex + 1]!"") +
            attributeIfContent("ResourceGroup", segments?sequence[resourceGroupIndex + 1]!"") +
            attributeIfContent("Provider", segments?sequence[providerIndex + 1]!"") +
            attributeIfContent("Parents", parents)]
    [#else]
        [@fatal
            message="Invalid scope from resourceId"
            context={ "ResourceId" : id }
        /]
        [#return {}]
    [/#if]
[/#function]

[#-- scope of a resource relative to the current runtime state. --]
[#function getResourceRelativeScope id]
    [#-- scope determination:                                                                       --]
    [#--    * determine current runtime scope.                                                      --]
    [#--    * compare with scope of evaluated resource.                                             --]
    [#--    * construct relativeScope - attributes indicate a variance from the current resource.   --]
    [#--    * assign a scope level - a label identifying the scope.                                 --]
    [#--        * ensure scope level does not go below the resource scope marker.                   --]
    [#--          The marker indicates the minimum scope to which a resource exists.                --]
    [#local resourceProfileScope = getAzureResourceProfile(getResourceType(id)).scope]
    [#local currentScope = {
        "Subscription" : accountObject.ProviderId,
        "ResourceGroup" : commandLineOptions.Deployment.ResourceGroup.Name
    }]

    [#if isPartOfCurrentDeploymentUnit(id)]
        [#local relativeScope = {}]
    [#else]
        [#local resourceId = getReference(AZURE_PROVIDER, id)]    
        [#if resourceId?has_content]
            [#local targetScope = getResourceScopeFromResourcePath(resourceId)]

            [#if !(targetScope?has_content)]
                [@fatal
                    message="Resource relative scope could not be determined."
                    context=
                    {
                            "ResourceId" : id,
                            "CurrentScope" : currentScope,
                            "TargetScope" : targetScope,
                            "RelativeScope" : relativeScope
                        }
                /]
            [/#if]

            [#local relativeScope = {} +
                attributeIfTrue("Subscription", !currentScope.Subscription?matches(targetScope.Subscription!""), targetScope.Subscription!"") +
                attributeIfTrue("ResourceGroup", !currentScope.ResourceGroup?matches(targetScope.ResourceGroup!""), targetScope.ResourceGroup!"")]
        [#else]
            [@fatal
                message="Could not find existing reference for Id"
                context={ "Id" : id }
            /]
        [/#if]
    [/#if]

    [#-- scope level --]
    [#-- The existence of attributes in the relativeScope object indicate --]
    [#-- cross-scope at that level.                                       --]
    [#local scopeLevels = ["template", "resourceGroup", "subscription", "pseudo"] ]
    [#if resourceProfileScope == "pseudo"]
        [#local relativeScopeLevel = "pseudo"]
    [#elseif relativeScope?keys?seq_contains("Subscription")]
        [#local relativeScopeLevel = "subscription"]
    [#elseif relativeScope?keys?seq_contains("ResourceGroup")]
        [#local relativeScopeLevel = "resourceGroup" ]
    [#else]
        [#local relativeScopeLevel = "template"]
    [/#if]
    [#-- Use the relative level only down to the level of the default. --]
    [#-- Some resources only exist at the higher scopes.               --]
    [#if scopeLevels?seq_index_of(relativeScopeLevel) < scopeLevels?seq_index_of(resourceProfileScope)]
        [#local relativeScope += { "Level" : resourceProfileScope }]
    [#else]
        [#local relativeScope += { "Level" : relativeScopeLevel }]
    [/#if]
    [#return relativeScope]
[/#function]

[#macro armResource
    id
    name
    profile
    identity={}
    location=""
    dependsOn=[]
    properties={}
    tags={}
    comments=""
    copy={}
    sku={}
    kind=""
    plan={}
    zones=[]
    resources=[]
    resourceGroupId=""
    subscriptionId=""
    parentId=""]

    [#if parentId?has_content]
        [#local resourceScope = getResourceRelativeScope(parentId)]
        [#local resourceGroupId = resourceScope.ResourceGroup!""]
        [#local subscriptionId = resourceScope.Subscription!""]
    [#else]
        [#local resourceScope = getResourceRelativeScope(id)]
    [/#if]
    [#local resourceProfile = getAzureResourceProfile(profile)]
    [#local templateOutputs = constructArmOutputsFromMappings(id, name, resourceScope.Level, resourceProfile.outputMappings)]
    [#local resourceLocation = resourceProfile.global?then("global", location)]

    [#-- Construct Current Resource Object --]
    [#if !(resourceScope.Level == "pseudo")]
        [#local resourceContent = {
                    "name": name,
                    "type": resourceProfile.type,
                    "apiVersion": resourceProfile.apiVersion,
                    "properties": properties
                } +
                attributeIfContent("identity", identity) +
                attributeIfContent("location", resourceLocation) +
                attributeIfContent("tags", tags) +
                attributeIfContent("comments", comments) +
                attributeIfContent("copy", copy) +
                attributeIfContent("sku", sku) +
                attributeIfContent("kind", kind) +
                attributeIfContent("plan", plan) +
                attributeIfContent("zones", zones) +
                attributeIfContent("resources", resources)]
    [/#if]

    [#-- Resource scopes above "template" should be nested inside of a --]
    [#-- "Deployment" resource. This resource is used to deploy across --]
    [#-- scopes (other resource groups or subscriptions), whilst       --]
    [#-- keeping the resource definition in the same deployment unit.  --]
    [#switch resourceScope.Level]

        [#case "subscription"]
        [#case "resourceGroup"]
            [#local deploymentResourceName = formatAzureResourceName(name, AZURE_DEPLOYMENT_RESOURCE_TYPE)]
            [#local deploymentOutputs = constructArmOutputsFromMappings(id, deploymentResourceName, resourceScope.Level, resourceProfile.outputMappings)]
            [@armResource
                id=formatResourceId(AZURE_DEPLOYMENT_RESOURCE_TYPE, id)
                name=formatAzureResourceName(name, AZURE_DEPLOYMENT_RESOURCE_TYPE)
                profile=AZURE_DEPLOYMENT_RESOURCE_TYPE
                properties=
                    {
                        "mode" : "Incremental",
                        "template": {
                            "$schema": ARMSchemas.Template,
                            "contentVersion": "1.0.0.0",
                            "parameters": {},
                            "resources": [resourceContent],
                            "outputs": constructArmOutputsFromMappings(
                                            id,
                                            name,
                                            "template",
                                            resourceProfile.outputMappings)
                        }
                    }
                resourceGroupId=resourceGroupId
                subscriptionId=subscriptionId
                dependsOn=dependsOn
            /]
            [@mergeWithJsonOutput
                name="outputs"
                content=deploymentOutputs
            /]
            [#break]

        [#case "template"]
            [#local resourceContent += {} +
                attributeIfContent("resourceGroup", resourceGroupId) +
                attributeIfContent("subscriptionId", subscriptionId) + 
                attributeIfContent("dependsOn", dependsOn)]
            [@addToJsonOutput
                name="resources"
                content=[resourceContent]
            /]
            [@mergeWithJsonOutput
                name="outputs"
                content=templateOutputs
            /]
            [#break]

        [#case "pseudo"]
            [@mergeWithJsonOutput
                name="outputs"
                content=templateOutputs
            /]
            [#break]

        [#default]
            [@fatal
                message="Unknown or missing resource scope."
                context={
                        "DefaultResourceScope" : resourceProfile.scope
                    } +
                    attributeIfContent("OverwriteScope", scope)
            /]
            [#break]

    [/#switch]
[/#macro]

[#macro arm_output_resource level="" include=""]

    [#-- Resources --]
    [#if include?has_content]
        [#include include?ensure_starts_with("/")]
    [#else]
        [@processFlows
            level=level
            framework=AZURE_RESOURCE_MANAGER_DEPLOYMENT_FRAMEWORK
            flows=commandLineOptions.Flow.Names
        /]
    [/#if]

    [#if getOutputContent("resources")?has_content || logMessages?has_content]
        [@toJSON
            {
                '$schema': ARMSchemas.Template,
                "contentVersion": "1.0.0.0",
                "parameters": getOutputContent("parameters"),
                "variables": getOutputContent("variables"),
                "resources": getOutputContent("resources"),
                "outputs":
                    getOutputContent("outputs") +
                    getArmTemplateCoreOutputs()
            } +
            attributeIfContent("HamletMessages", logMessages)
        /]
    [/#if]
[/#macro]


[#-- Initialise the possible outputs to make sure they are available to all steps --]
[@initialiseJsonOutput name="resources" /]
[@initialiseJsonOutput name="outputs" /]

[#assign AZURE_OUTPUT_RESOURCE_TYPE = "resource" ]

[@addGenerationContractStepOutputMapping
    provider=AZURE_PROVIDER
    subset="template"
    outputType=AZURE_OUTPUT_RESOURCE_TYPE
    outputFormat=""
    outputSuffix="template.json"
/]
