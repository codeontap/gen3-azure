[#ftl]
[#macro azure_network_arm_deployment_generationcontract occurrence]
  [@addDefaultGenerationContract subsets="template" /]
[/#macro]

[#macro azure_network_arm_deployment occurrence]
  [@debug message="Entering" context=occurrence enabled=false /]

  [#local core = occurrence.Core]
  [#local solution = occurrence.Configuration.Solution]
  [#local resources = occurrence.State.Resources]

  [#local vnetId = resources["vnet"].Id]
  [#local vnetName = resources["vnet"].Name]
  [#local vnetCIDR = resources["vnet"].Address]

  [#if deploymentSubsetRequired(NETWORK_COMPONENT_TYPE, true)]

    [#-- 1. Vnet --]
    [@createVNet
      id=vnetId
      name=vnetName
      location=regionId
      addressSpacePrefixes=[vnetCIDR]
    /]

    [#-- 2. NetworkSecurityGroup --]
    [#local networkSecurityGroupId = resources["networkSecurityGroup"].Id]
    [#local networkSecurityGroupName = resources["networkSecurityGroup"].Name]

    [@createNetworkSecurityGroup
      id=networkSecurityGroupId
      name=networkSecurityGroupName
      location=regionId
    /]

    [#-- Seperate NSG for the ELB Subnet                                              --]
    [#-- Application Gateways have some very specific requirements around NSG         --]
    [#-- rules that must be in place. At present time they are overly-open in         --]
    [#-- the access that they grant. To reduce this, the ELB subnet which will        --]
    [#-- be used by the App Gateways will get their own NSG. This can be              --]
    [#-- removed once the NSG Rules can be associated with the Azure Service          --]
    [#-- tag "GatewayManager" https://github.com/MicrosoftDocs/azure-docs/issues/38691--]
    [#if (resources["subnets"]["elb"]!{})?has_content]

      [#if resources["elbNSG"]?has_content]
        [#local elbNSG = resources["elbNSG"]]
      [/#if]

      [@createNetworkSecurityGroup
        id=elbNSG.Id
        name=elbNSG.Name
        location=regionId
      /]

      [@createNetworkSecurityGroupSecurityRule
        id=formatDependentSecurityRuleId("elb", "AllowGatewayManager")
        name=formatAzureResourceName(
                formatName("elb", "AllowGatewayManager"),
                AZURE_VIRTUAL_NETWORK_SECURITY_GROUP_SECURITY_RULE_RESOURCE_TYPE,
                elbNSG.Name)
        description="Grants the GatewayManager access to App Gateway resources"
        destinationPortProfileName="gatewaymanager"
        sourceAddressPrefix="*"
        destinationAddressPrefix="*"
        access="allow"
        priority=100
        direction="Inbound"
        dependsOn=
          [
            elbNSG.Reference
          ]
      /]

      [@createNetworkSecurityGroupSecurityRule
        id=formatDependentSecurityRuleId("elb", "AllowAzureLoadBalancer")
        name=formatAzureResourceName(
                formatName("elb", "AllowAzureLoadBalancer"),
                AZURE_VIRTUAL_NETWORK_SECURITY_GROUP_SECURITY_RULE_RESOURCE_TYPE,
                elbNSG.Name)
        description="Grants the GatewayManager access to App Gateway resources"
        destinationPortProfileName="any"
        sourceAddressPrefix="AzureLoadBalancer"
        destinationAddressPrefix="*"
        access="allow"
        priority=110
        direction="Inbound"
        dependsOn=
          [
            elbNSG.Reference
          ]
      /]

    [/#if]

    [#-- 3. Subnets for every tier --]
    [#if (resources["subnets"]!{})?has_content]

      [#local subnetResources = resources["subnets"]]
      [#list subnetResources as tierId,subnets]

        [#local networkTier = getTier(tierId)]
        [#local tierNetwork = getTierNetwork(tierId)]

        [#local networkLink = tierNetwork.Link!{}]
        [#local routeTableId = tierNetwork.RouteTable!""]
        [#local networkACLId = tierNetwork.NetworkACL!""]

        [#if !networkLink?has_content || !routeTableId?has_content || !networkACLId?has_content]
          [@fatal
            message="Tier Network configuration incomplete"
            context=
              tierNetwork +
              {
                "Link" : networkLink,
                "RouteTable" : routeTableId,
                "NetworkACL" : networkACLId
              }
          /]
        [/#if]

        [#local routeTableLink = getLinkTarget(occurrence, networkLink + { "RouteTable" : routeTableId }, false)]
        [#local networkACLLink = getLinkTarget(occurrence, networkLink + { "NetworkACL" : networkACLId }, false)]
        [#local routeTableResource = routeTableLink.State.Resources["routeTable"]!{}]

        [#local subnet = subnets.subnet]
        [#local subnetIndex = subnets?index]
        [#local subnetName = formatAzureResourceName(
          subnet.Name,
          getResourceType(subnet.Id),
          vnetName)]

        [#-- Determine dependencies --]
        [#local dependencies = [
            getReference(AZURE_PROVIDER, {"Id": vnetId, "Name": vnetName})
        ]]

        [#if subnetIndex > 0]
          [#local previousSubnet = resources["subnets"]?values[subnetIndex - 1].subnet]
          [#local dependencies += [
            getReference(
              previousSubnet.Id,
              formatAzureResourceName(
                previousSubnet.Name,
                AZURE_SUBNET_RESOURCE_TYPE,
                vnetName
              )
            )
          ]]
        [/#if]

        [#-- Retrieve the NetworkEndpoint's from the Gateway component and prepare the Management Tier subnet for them --]
        [#local networkEndpointGroups = []]
        [#list solution.Links?values as link]
          [#if link?is_hash]

            [#local linkTarget = getLinkTarget(occurrence, link + { "Destination" : "default" }, false)]

            [#if !linkTarget?has_content]
              [#continue]
            [/#if]

            [#local linkTargetConfiguration = linkTarget.Configuration]

            [#switch linkTarget.Core.Type]
              [#case NETWORK_GATEWAY_DESTINATION_COMPONENT_TYPE]
                [#if linkTarget.State.Attributes.Engine = "vpcendpoint" || linkTarget.State.Attributes.Engine = "privateservice" ]
                  [#local linkNetworkEndpointGroups = linkTargetConfiguration.Solution.NetworkEndpointGroups]
                  [#list linkNetworkEndpointGroups as group]
                    [#if !networkEndpointGroups?seq_contains(group)]
                      [#local networkEndpointGroups += [group]]
                    [/#if]
                  [/#list]
                [/#if]
                [#break]
            [/#switch]

          [/#if]
        [/#list]

        [#local networkEndpoints = getNetworkEndpoints(networkEndpointGroups, "a", regionId)]

        [#local serviceEndpoints = []]
        [#local serviceEndpointPolicies = []]
        [#if tierId == "mgmt"]
          [#list networkEndpoints?keys as endpointId]
            [#local serviceEndpoints += [getSubnetServiceEndpoint(endpointId, [regionId])]]
          [/#list]
        [/#if]

        [#-- Add routeTable details if applicable --]
        [#if routeTableResource?has_content]
          [#local dependencies += [getReference(AZURE_PROVIDER, routeTableResource)]]
        [/#if]

        [#if networkTier.Name == "elb"]
          [#local networkSecurityGroupReference = getSubResourceReference(elbNSG.Reference)]
          [#local dependencies += [elbNSG.Reference]]
        [#else]
          [#local networkSecurityGroupReference = getSubResourceReference(
            getReference(AZURE_PROVIDER, {"Id": networkSecurityGroupId, "Name": networkSecurityGroupName})
          )]
        [/#if]

        [@createSubnet
          id=subnet.Id
          name=subnetName
          addressPrefix=subnet.Address
          networkSecurityGroup=networkSecurityGroupReference
          routeTable={} + routeTableResource?has_content?then(
            getSubResourceReference(getReference(AZURE_PROVIDER, routeTableResource)),
            {}
          )
          serviceEndpoints=serviceEndpoints
          dependsOn=dependencies
        /]

        [#local networkACLConfiguration = networkACLLink.Configuration.Solution]

        [#list networkACLConfiguration.Rules as ruleId, ruleConfig]

          [#--
            Rules are Subnet-specific.
            Where an IPAddressGroup is found to be _localnet, use the subnet CIDR instead.
          --]
          [#if ruleConfig.Source.IPAddressGroups?seq_contains("_localnet")]
            [#local direction = "Outbound"]
            [#local sourceAddressPrefix = subnet.Address]
          [#else]
            [#local direction = "Inbound"]
            [#local sourceAddressPrefix = getGroupCIDRs(
              ruleConfig.Source.IPAddressGroups,
              true,
              occurrence)[0]]
          [/#if]

          [#if ruleConfig.Destination.IPAddressGroups?seq_contains("_localnet")]
            [#local destinationAddressPrefix = subnet.Address]
          [#else]
            [#local destinationAddressPrefix = getGroupCIDRs(
              ruleConfig.Destination.IPAddressGroups,
              true,
              occurrence)[0]]
          [/#if]

          [#if subnet.Name == "elb"]
            [#local nsgName = elbNSG.Name]
            [#local nsgId = elbNSG.Id]
          [#else]
            [#local nsgName = networkSecurityGroupName]
            [#local nsgId = networkSecurityGroupId]
          [/#if]

          [@createNetworkSecurityGroupSecurityRule
            id=formatDependentSecurityRuleId(subnet.Id, ruleId)
            name=formatAzureResourceName(
              formatName(tierId,ruleId),
              getResourceType(formatDependentSecurityRuleId(vnetId, formatName(tierId,ruleId))),
              nsgName)
            description=description
            destinationPortProfileName=ruleConfig.Destination.Port
            sourceAddressPrefix=sourceAddressPrefix
            destinationAddressPrefix=destinationAddressPrefix
            access=ruleConfig.Action
            priority=(ruleConfig.Priority + tierId?index + ruleId?index)
            direction=direction
            dependsOn=
              [
                getReference(AZURE_PROVIDER, {"Id": nsgId, "Name": nsgName})
              ]
          /]

        [/#list]
      [/#list]
    [/#if]

    [#-- Sub Components --]
    [#list occurrence.Occurrences![] as subOccurrence]

      [#local core = subOccurrence.Core]
      [#local solution = subOccurrence.Configuration.Solution]
      [#local resources = subOccurrence.State.Resources]

      [@debug message="Suboccurrence" context=subOccurrence enabled=false /]

      [#-- 4. RouteTables --]
      [#if core.Type == NETWORK_ROUTE_TABLE_COMPONENT_TYPE &&
        core.SubComponent.Name != "default"]

        [#local routeTable = resources["routeTable"]]

        [@createRouteTable
          id=routeTable.Id
          name=routeTable.Name
          location=regionId
        /]

      [/#if]
    [/#list]

    [#-- TODO(rossmurr4y): Flow Logs object is not currently supported, though exists when created
    via PowerShell. This is being developed by Microsoft and expected Jan 2020 - will need to revisit
    this implimentation at that time to ensure this object remains correct.
    https://feedback.azure.com/forums/217313-networking/suggestions/37713784-arm-template-support-for-nsg-flow-logs
    --]
    [#-- 6. NetworkWatcher : Flow Logs --]
    [#if (resources["flowlogs"]!{})?has_content]
      [#local flowLogResources = resources["flowlogs"]]
      [#local flowLogNSGId = flowLogResources["networkWatcherFlowlog"].Id]
      [#local flowLogNSGName = flowLogResources["networkWatcherFlowlog"].Name]

      [#local flowLogStorageId = getReference(
        formatResourceId(
          AZURE_STORAGEACCOUNT_RESOURCE_TYPE,
          core.Id
        )
      )]

      [@createNetworkWatcherFlowLog
        id=flowLogNSGId
        name=flowLogNSGName
        targetResourceId=getReference(AZURE_PROVIDER, {"Id": networkSecurityGroupId, "Name": networkSecurityGroupName})
        storageId=flowLogStorageId
        enabled=true
        trafficAnalyticsInterval="0"
        retentionPolicyEnabled=true
        retentionDays="7"
        formatType="JSON"
        formatVersion="0"
        dependsOn=
          [
            getReference(AZURE_PROVIDER,flowLogStorageId)
          ]
      /]
    [/#if]
  [/#if]
[/#macro]
