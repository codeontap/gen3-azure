[#ftl]

[#macro azure_computecluster_arm_state occurrence parent={}]

    [#local core = occurrence.Core]
    [#local solution = occurrence.Configuration.Solution]

    [#local storageRole = "StorageBlobDataReader"]

    [#local scaleSetId  = formatResourceId(AZURE_VIRTUALMACHINE_SCALESET_RESOURCE_TYPE, core.ShortName)]
    [#local nicId       = formatResourceId(AZURE_NETWORK_INTERFACE_RESOURCE_TYPE, core.ShortName)]
    [#local roleId      = formatResourceId(AZURE_ROLE_ASSIGNMENT_RESOURCE_TYPE, storageRole)]
    [#local autoscaleId = formatResourceId(AZURE_AUTOSCALE_SETTINGS_RESOURCE_TYPE, core.ShortName)]
    [#local extensionId = formatResourceId(AZURE_VIRTUALMACHINE_SCALESET_EXTENSION_RESOURCE_TYPE, core.ShortName)]

    [#local scalesetName  = formatAzureResourceName(core.ShortName, AZURE_VIRTUALMACHINE_SCALESET_RESOURCE_TYPE)]
    [#local nicName       = formatAzureResourceName(core.ShortName, AZURE_NETWORK_INTERFACE_RESOURCE_TYPE)]
    [#local roleName      = userRoles[storageRole].Id]
    [#local autoscaleName = formatAzureResourceName(core.ShortName, AZURE_AUTOSCALE_SETTINGS_RESOURCE_TYPE)]
    [#local extensionName = formatAzureResourceName(core.ShortName, AZURE_VIRTUALMACHINE_SCALESET_EXTENSION_RESOURCE_TYPE, scalesetName)]

    [#-- NSG Rules --]
    [#local occurrenceNetwork = getOccurrenceNetwork(occurrence)]
    [#local networkLink = occurrenceNetwork.Link!{} ]
    [#local networkLinkTarget = getLinkTarget(occurrence, networkLink, false) ]

    [#if ! networkLinkTarget?has_content ]
        [@fatal message="Network could not be found" context=networkLink /]
        [#return]
    [/#if]

    [#local networkResources = networkLinkTarget.State.Resources ]
    [#local nsg = networkResources["networkSecurityGroup"]]

    [#local nsgRules = {}]
    [#list solution.Ports?values as port ]
        [#if !(port.LB.Configured)]
            [#local portCIDRs = getGroupCIDRs(port.IPAddressGroups, true, occurrence)]
            [#if portCIDRs?has_content]
                
                [#local cidrCount = portCIDRs?size]
                [#local nsgRuleId   = formatResourceId(AZURE_VIRTUAL_NETWORK_SECURITY_GROUP_SECURITY_RULE_RESOURCE_TYPE, port.Name)]
                [#local nsgRuleName   = formatAzureResourceName(port.Name, AZURE_VIRTUAL_NETWORK_SECURITY_GROUP_SECURITY_RULE_RESOURCE_TYPE, nsg.Name)]

                [#local nsgRules +=
                    {   
                        port.Name : {
                            "Id" : nsgRuleId,
                            "Name" : nsgRuleName,
                            "Type" : AZURE_VIRTUAL_NETWORK_SECURITY_GROUP_SECURITY_RULE_RESOURCE_TYPE,
                            "Reference" : getReference(AZURE_PROVIDER, {"Id": nsgRuleId, "Name": nsgRuleName}),
                            "Port" : port.Name
                        } +
                        attributeIfTrue("CIDR", (cidrCount == 1), portCIDRs[0]) +
                        attributeIfTrue("CIDRs", (cidrCount > 1), portCIDRs)
                    }]
            [/#if]
        [/#if]
    [/#list]

    [#-- If there are any NSG Rules defined, then we need a Public IP --]
    [#local publicIp = {}]
    [#if nsgRules??]

        [#local ipId       = formatResourceId(AZURE_PUBLIC_IP_ADDRESS_RESOURCE_TYPE, core.ShortName)]
        [#local ipName     = formatAzureResourceName(core.ShortName, AZURE_PUBLIC_IP_ADDRESS_RESOURCE_TYPE)]

        [#local publicIp +=
            {
                "Id" : ipId,
                "Name" : ipName,
                "Type" : AZURE_PUBLIC_IP_ADDRESS_RESOURCE_TYPE,
                "Reference" : getReference(AZURE_PROVIDER, {"Id": ipId, "Name": ipName})
            }]
    [/#if]

    [#assign componentState =
        {
            "Resources" : {
                "role" : {
                    "Id" : roleId,
                    "Name" : roleName,
                    "Type" : AZURE_ROLE_ASSIGNMENT_RESOURCE_TYPE,
                    "Reference" : getReference(AZURE_PROVIDER, {"Id": roleId, "Name": roleName}),
                    "Assignment" : storageRole
                },
                "scaleSet" : {
                    "Id" : scaleSetId,
                    "Name" : scalesetName,
                    "Type" : AZURE_VIRTUALMACHINE_SCALESET_RESOURCE_TYPE,
                    "PrincipalId" : getReference(AZURE_PROVIDER, {"Id": scaleSetId, "Name": scaleSetName}, ALLOCATION_ATTRIBUTE_TYPE),
                    "Reference" : getReference(AZURE_PROVIDER, {"Id": scaleSetId, "Name": scalesetName})
                },
                "networkInterface" : {
                    "Id" : nicId,
                    "Name" : nicName,
                    "Type" : AZURE_NETWORK_INTERFACE_RESOURCE_TYPE,
                    "Reference": getReference(AZURE_PROVIDER, {"Id": nicId, "Name": nicName})
                },
                "autoscale" : {
                    "Id" : autoscaleId,
                    "Name" : autoscaleName,
                    "Type" : AZURE_AUTOSCALE_SETTINGS_RESOURCE_TYPE,
                    "Reference" : getReference(AZURE_PROVIDER,{"Id": autoscaleId, "Name": autoscaleName})
                },
                "bootstrap" : {
                    "Id" : extensionId,
                    "Name" : extensionName,
                    "Type" : AZURE_VIRTUALMACHINE_SCALESET_EXTENSION_RESOURCE_TYPE,
                    "Reference" : getReference(AZURE_PROVIDER, {"Id": extensionId, "Name": extensionName})
                },
                "nsgRules": nsgRules,
                "publicIp" : publicIp
            },
            "Attributes" : {},
            "Roles" : {
                "Inbound" : {},
                "Outbound" : {}
            }
        }
    ]
[/#macro]