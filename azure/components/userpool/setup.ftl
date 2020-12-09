[#ftl]

[#macro azure_userpool_arm_deployment_generationcontract occurrence]
    [@addDefaultGenerationContract subsets=["prologue"] /]
[/#macro]

[#macro azure_userpool_arm_deployment occurrence]
    [@debug message="Entering" context=occurrence enabled=false /]

    [#local core = occurrence.Core]
    [#local solution = occurrence.Configuration.Solution]

    [#local userpool =  occurrence.State.Resources["userpool"]]

    [#local generateSecret = false]

    [#-- Baseline Links --]
    [#local baselineLinks = getBaselineLinks(occurrence, ["SSHKey"], false, false)]
    [#local baselineAttributes = baselineLinks["SSHKey"].State.Attributes]
    [#local keyvaultId = baselineAttributes["KEYVAULT_ID"]]
    [#local keyvault = getReference(AZURE_PROVIDER, keyvaultId, NAME_ATTRIBUTE_TYPE)]

    [#-- Instantiate CLI Args --]
    [#local replyUrls = []]
    [#local logoutUrls = []]
    [#local creationcliArgs = {}]
    [#local client = {}]
    [#-- Not all properties can be set on creation --]
    [#local updatesCliArgs = {}]

    [#list occurrence.Occurrences![] as subOccurrence]

        [#local subCore = subOccurrence.Core]
        [#local subSolution = subOccurrence.Configuration.Solution]
        [#local subResources = subOccurrence.State.Resources]
        [#local subAttributes = subOccurrence.State.Attributes]

        [#if !subSolution.Enabled]
            [#continue]
        [/#if]

        [#-- Resource SubComponent Processing --]
        [#if subCore.Type == USERPOOL_RESOURCE_COMPONENT_TYPE]

            [#local subLinkTarget = getLinkTarget(subOccurrence, subSolution.Server.Link, false)]

            [#if !subLinkTarget?has_content]
                [#continue]
            [/#if]

            [#local subLinkTargetAttributes = subLinkTarget.State.Attributes]
            [#if ((subLinkTargetAttributes[subSolution.Server.LinkAttribute])!"")?has_content ]
                [#local replyUrls += [subLinkTargetAttributes[subSolution.Server.LinkAttribute]]]
            [#else]
                [@fatal
                    message="Server Link Attribute not found"
                    context=subSolution.Server
                    detail="The LinkAttribute specified could not be found on the provided link"
                /]
            [/#if]

        [/#if]

        [#-- Client Processing --]
        [#if subCore.Type == USERPOOL_CLIENT_COMPONENT_TYPE]

            [#local client = subResources["client"]]

            [#list subSolution.Links?values as link]

                [#local linkTarget = getLinkTarget(subOccurrence, link)]

                [@debug message="Link Target" context=linkTarget enabled=false /]

                [#if !linkTarget?has_content]
                    [#continue]
                [/#if]

                [#local linkTargetCore = linkTarget.Core]
                [#local linkTargetConfiguration = linkTarget.Configuration]
                [#local linkTargetResources = linkTarget.State.Resources]
                [#local linkTargetAttributes = linkTarget.State.Attributes]

                [#switch linkTargetCore.Type]

                    [#case "external" ]
                    [#case EXTERNALSERVICE_COMPONENT_TYPE]

                        [#if linkTargetAttributes["AUTH_CALLBACK_URL"]?has_content]
                            [#local replyUrls += [linkTargetAttributes["AUTH_CALLBACK_URL"]]]
                        [/#if]

                        [#if linkTargetAttributes["AUTH_SIGNOUT_URL"]?has_content]
                            [#local logoutUrls += [linkTargetAttributes["AUTH_SIGNOUT_URL"]]]
                        [/#if]

                        [#break]

                    [#case USERPOOL_AUTHPROVIDER_COMPONENT_TYPE]
                        [#if linkTargetConfiguration.Solution.Enabled]
                            [#local identityProviders += [ linkTargetAttributes["PROVIDER_NAME"]]]
                        [/#if]
                        [#break]

                [/#switch]
            [/#list]

            [#if deploymentSubsetRequired("prologue", false)]

                [#local flows = subSolution.OAuth.Flows![]]
                [#local otherTenants = subSolution.azure\:AllowOtherTenants!false]
                [#if subSolution.ClientGenerateSecret!false]
                    [#local generateSecret = true]
                [/#if]

                [#-- CLI Args in the format {"arg": "value"} --]
                [#-- We can then output all args to the CLI  --]
                [#local creationcliArgs += {
                    "display-name": client.Name
                } +
                    attributeIfTrue("oauth2-allow-implicit-flow", flows?seq_contains("implicit"), true) +
                    attributeIfTrue("available-to-other-tenants", otherTenants, otherTenants)
                ]

            [/#if]

        [/#if]

    [/#list]

    [#local creationcliArgs += {} +
        attributeIfContent("reply-urls", replyUrls?join(' '))]

    [#local updatesCliArgs += {} +
        attributeIfContent("set", logoutUrls?join(' '))]

    [#-- Format Args as CLI Parameters --]
    [#local args = []]
    [#local updateArgs = []]
    [#list creationcliArgs as key,value]
        [#if value?is_boolean]
            [#local formattedValue = value?c]
        [#elseif value?is_sequence]
            [#-- all array args on cli command are space-seperated --]
            [#local formattedValue = value?join(" ")]
        [#else]
            [#local formattedValue = value]
        [/#if]

        [#local arg = (key?ensure_starts_with("--")) + " " + formattedValue]
        [#local args += [arg]]
    [/#list]

    [#if updatesCliArgs?has_content]
        [#local updatesCliArgs += {"output" : "none"}]
        [#list updatesCliArgs as key,value]
            [#local updateArg = (key?ensure_starts_with("--")) + " " + value]
            [#local updateArgs += [updateArg]]
        [/#list]
    [/#if]

    [#-- Create App Registration --]
    [@addToDefaultBashScriptOutput
        content=
            [
                " # AAD App Registration",
                " case $\{DEPLOYMENT_OPERATION} in",
                "   delete)"
            ] +
            identifier?has_content?then(
                [
                    "       # Remove AAD App Registration",
                    "       info \"Removing AAD App Registration\"",
                    "       result=$(az ad app delete --id " + identifier + ")",
                    "       ;;"
                ],
                [
                    "       # Remove AAD App Registration",
                    "       info \"No App Registration Identifier Found. Skipping.\"",
                    "       ;;"
                ]
            ) +
            [
                "   create|update)",
                "       az ad app create " + args?join(" ") + " > $tmp/registration.json",
                "       objectId=$(runJQ -r '.objectId' < $tmp/registration.json)",
                "       clientId=$(runJQ -r '.appId' < $tmp/registration.json)"
            ] +
            (updateArgs?has_content)?then(
                [
                    "       # Update AAD App Registration Properties",
                    "       az ad app update --id $(echo \"$\{objectId}\") " updateArgs?join(" ")
                ],
                []
            ) +
            generateSecret?then(
                [
                    "       # Add Certificate as Client Secret",
                    "       az ad app credential reset --create-cert \\",
                    "           --keyvault " + keyvault + " \\",
                    "           --cert " + formatName(client.Name, "appregistration") + " \\",
                    "           --id $(echo \"$\{objectId}\") > /dev/null"
                ],
                []
            ) +
            client?has_content?then(
                pseudoArmStackOutputScript(
                    "Client Registration",
                    {
                        userpool.Id : userpool.Name,
                        client.Id : "$\{objectId}",
                        client.ClientAppId : "$\{clientId}"
                    },
                    "client"
                ) +
                [
                    "       ;;",
                    "   esac",
                    "       "
                ],
                []
            )
    /]

[/#macro]
