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

[#macro armOutput name type value condition=""]
    [@mergeWithJsonOutput
        name="outputs"
        content=
            {
                name : {
                    "type" : type,
                    "value" : value
                } +
                attributeIfContent("condition", condition)
            }
    /]
[/#macro]

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

    [#list getArmTemplateCoreOutputs(region, accountObject.AzureId, commandLineOptions.Deployment.ResourceGroup.Name) as key,value]
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
    parentNames=[]]

    [#local resourceProfile = getAzureResourceProfile(profile)]
    [#local resourceLocation = resourceProfile.global?then("global", location)]

    [#if !(resourceProfile.type == "pseudo")]
        [@addToJsonOutput
            name="resources"
            content=[
                {
                    "name": name,
                    "type": resourceProfile.type,
                    "apiVersion": resourceProfile.apiVersion,
                    "properties": properties
                } +
                attributeIfContent("identity", identity) +
                attributeIfContent("location", resourceLocation) +
                attributeIfContent("dependsOn", dependsOn) +
                attributeIfContent("tags", tags) +
                attributeIfContent("comments", comments) +
                attributeIfContent("copy", copy) +
                attributeIfContent("sku", sku) +
                attributeIfContent("kind", kind) +
                attributeIfContent("plan", plan) +
                attributeIfContent("zones", zones) +
                attributeIfContent("resources", resources)
            ]
        /]
    [/#if]

    [#list resourceProfile.outputMappings as attributeType,attributes]

        [#switch attributeType]
            [#case DICTIONARY_ATTRIBUTE_TYPE]
                [#local type = "object"]
                [#break]

            [#default]
                [#local type = "string"]
                [#break]
        [/#switch]

        [#list attributes as attributeName,attributeValue]

            [#switch attributeValue]
            
                [#case "id"]
                    [#local outputName = id]
                    [#local value = getReference(id, name)]
                    [#break]

                [#case "pseudo"]

                    [@addToDefaultBashScriptOutput
                        content=
                        pseudoArmStackOutputScript(name + " Values", { id : name })
                    /]

                    [#break]

                [#default]
                    [#local propertySections = attributeValue?split(".")]
                    [#local outputName = formatAttributeId(id, propertySections)]
                    [#local typeFull = getAzureResourceProfile(getResourceType(id)).type]
                    [#local value = getReference(id, name, typeFull, attributeType, "", "", true, attributeValue)]
                    [#break]

            [/#switch]

            [#if outputName??]
                [@armOutput
                    name=outputName
                    type=type
                    value=value
                /]
            [/#if]

        [/#list]
    [/#list]
[/#macro]

[#macro armPseudoResource id name profile]
    [@armResource
        id=id
        name=name
        profile=profile
    /]
[/#macro]

[#macro arm_output_resource level="" include=""]

    [#-- Resources --]
    [#if include?has_content]
        [#include include?ensure_starts_with("/")]
    [#else]
        [@processComponents level /]
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
            attributeIfContent("COTMessages", logMessages)
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
