[#ftl]

[#assign networkResourceProfiles = {
  AZURE_APPLICATION_SECURITY_GROUP_RESOURCE_TYPE : {
    "apiVersion" : "2019-04-01",
    "type" : "Microsoft.Network/applicationSecurityGroups",
    "outputMappings" : {}
  },
  AZURE_NETWORK_INTERFACE_RESOURCE_TYPE : {
    "apiVersion" : "2019-09-01",
    "type" : "Microsoft.Network/networkInterfaces",
    "outputMappings" : {}
  },
  AZURE_PUBLIC_IP_ADDRESS_PREFIX_RESOURCE_TYPE : {
    "apiVersion" : "2019-11-01",
    "type" : "Microsoft.Network/publicIPPrefixes",
    "outputMappings" : {
      REFERENCE_ATTRIBUTE_TYPE : {
        "Property" : "id"
      }
    }
  },
  AZURE_PUBLIC_IP_ADDRESS_RESOURCE_TYPE : {
    "apiVersion" : "2019-09-01",
    "type" : "Microsoft.Network/publicIPAddresses",
    "outputMappings" : {
      IP_ADDRESS_ATTRIBUTE_TYPE : {
        "Property" : "properties.ipAddress"
      }
    }
  },
  AZURE_ROUTE_TABLE_RESOURCE_TYPE : {
    "apiVersion" : "2019-02-01",
    "type" : "Microsoft.Network/routeTables",
    "outputMappings" : {}
  },
  AZURE_ROUTE_TABLE_ROUTE_RESOURCE_TYPE : {
    "apiVersion" : "2019-02-01",
    "type" : "Microsoft.Network/routeTables/routes",
    "outputMappings" : {}
  },
  AZURE_SERVICE_ENDPOINT_POLICY_RESOURCE_TYPE : {
    "apiVersion" : "2019-02-01",
    "type" : "Microsoft.Network/serviceEndpointPolicies",
    "outputMappings" : {}
  },
  AZURE_SERVICE_ENDPOINT_POLICY_DEFINITION_RESOURCE_TYPE : {
    "apiVersion" : "2019-02-01",
    "type" : "Microsoft.Network/serviceEndpointPolicies/serviceEndpointPolicyDefinitions",
    "outputMappings" : {}
  },
  AZURE_SUBNET_RESOURCE_TYPE : {
    "apiVersion" : "2019-02-01",
    "type" : "Microsoft.Network/virtualNetworks/subnets",
    "outputMappings" : {
      REFERENCE_ATTRIBUTE_TYPE : {
        "Property" : "id"
      }
    }
  },
  AZURE_VIRTUAL_NETWORK_RESOURCE_TYPE : {
    "apiVersion" : "2019-02-01",
    "type" : "Microsoft.Network/virtualNetworks",
    "outputMappings" : {
      REFERENCE_ATTRIBUTE_TYPE : {
        "Property" : "id"
      }
    }
  },
  AZURE_VIRTUAL_NETWORK_PEERING_RESOURCE_TYPE : {
    "apiVersion" : "2019-02-01",
    "type" : "Microsoft.Network/virtualNetworks/virtualNetworkPeerings",
    "outputMappings" : {}
  },
  AZURE_VIRTUAL_NETWORK_SECURITY_GROUP_RESOURCE_TYPE : {
    "apiVersion" : "2019-02-01",
    "type" : "Microsoft.Network/networkSecurityGroups",
    "outputMappings" : {}
  },
  AZURE_VIRTUAL_NETWORK_SECURITY_GROUP_SECURITY_RULE_RESOURCE_TYPE : {
    "apiVersion" : "2019-04-01",
    "type" : "Microsoft.Network/networkSecurityGroups/securityRules",
    "outputMappings" : {}
  },
  AZURE_NETWORK_WATCHER_RESOURCE_TYPE : {
    "apiVersion" : "2019-04-01",
    "type" : "Microsoft.Network/networkWatchers",
    "outputMappings" : {}
  },
  AZURE_PRIVATE_DNS_ZONE_RESOURCE_TYPE : {
    "apiVersion" : "2018-09-01",
    "type" : "Microsoft.Network/privateDnsZones",
    "outputMappings" : {}
  },
  AZURE_PRIVATE_DNS_ZONE_VNET_LINK_RESOURCE_TYPE : {
    "apiVersion" : "2018-09-01",
    "type" : "Microsoft.Network/privateDnsZones/virtualNetworkLinks",
    "outputMappings" : {}
  }
}]

[#list networkResourceProfiles as resourceType,resourceProfile]
  [@addResourceProfile
    service=AZURE_NETWORK_SERVICE
    resource=resourceType
    profile=resourceProfile
  /]
[/#list]

[#macro createApplicationSecurityGroup id name location tags={} dependsOn=[]]
  [@armResource
    id=id
    name=name
    profile=AZURE_APPLICATION_SECURITY_GROUP_RESOURCE_TYPE
    location=location
    tags=tags
    dependsOn=dependsOn
  /]
[/#macro]

[#macro createNetworkSecurityGroupSecurityRule
  id
  name  
  access
  direction
  sourceAddressPrefix=""
  sourceAddressPrefixes=[]
  sourceApplicationSecurityGroups=[]
  destinationPortProfileName=""
  destinationAddressPrefix=""
  destinationAddressPrefixes=[]
  destinationApplicationSecurityGroups=[]
  description=""
  priority=4096
  tags={}
  dependsOn=[]]

  [#local destinationPortProfile = ports[destinationPortProfileName]]
  [#if destinationPortProfileName == "any"]
    [#local destinationPort = "*"]
  [#else]
    [#local destinationPort = isPresent(destinationPortProfile.PortRange)?then(
      destinationPortProfile.PortRange.From?c + "-" + destinationPortProfile.PortRange.To?c,
      destinationPortProfile.Port?c?string)]
  [/#if]

  [#--
    Azure will generate alerts if you provide source-port range/s as port filtering is
    primarily on the destination. Their recommendation is to specify "any" ("*") port.
  --]
  [@armResource
    id=id
    name=name
    profile=AZURE_VIRTUAL_NETWORK_SECURITY_GROUP_SECURITY_RULE_RESOURCE_TYPE
    dependsOn=dependsOn
    properties=  
      {
        "access" : access,
        "direction" : direction,
        "protocol" : destinationPortProfile.IPProtocol?replace("all", "*"),
        "sourcePortRange": "*"
      } +
      attributeIfContent("sourceAddressPrefix", formatAzureIPAddress(sourceAddressPrefix)) +
      attributeIfContent("sourceAddressPrefixes", formatAzureIPAddresses(sourceAddressPrefixes)) +
      attributeIfContent("sourceApplicationSecurityGroups", sourceApplicationSecurityGroups) +
      attributeIfContent("destinationPortRange", destinationPort) +
      attributeIfContent("destinationAddressPrefix", formatAzureIPAddress(destinationAddressPrefix)) +
      attributeIfContent("destinationAddressPrefixes", formatAzureIPAddresses(destinationAddressPrefixes)) +
      attributeIfContent("destinationApplicationSecurityGroups", destinationApplicationSecurityGroups) +
      attributeIfContent("description", description) +
      attributeIfContent("priority", priority)
    tags=tags
  /]
  
[/#macro]

[#macro createRouteTableRoute
  id
  name
  nextHopType 
  addressPrefix="" 
  nextHopIpAddress=""
  dependsOn=[]
  tags={}]

  [@armResource
    id=id
    name=name
    profile=AZURE_ROUTE_TABLE_ROUTE_RESOURCE_TYPE
    properties={ "nextHopType" : nextHopType } + 
      attributeIfContent("addressPrefix", addressPrefix) +
      attributeIfContent("nextHopIpAddress", nextHopIpAddress)
    dependsOn=dependsOn
    tags=tags
  /]

[/#macro]

[#macro createRouteTable
  id
  name
  routes=[]
  disableBgpRoutePropagation=false
  location=""
  tags={}
  dependsOn=[]]

  [@armResource
    id=id
    name=name
    profile=AZURE_ROUTE_TABLE_RESOURCE_TYPE
    location=location
    tags=tags
    properties={} +
      attributeIfContent("routes", routes) +
      attributeIfTrue("disableBgpRoutePropagation", disableBgpRoutePropagation, disableBgpRoutePropagation)
    dependsOn=dependsOn
  /]

[/#macro]

[#macro createNetworkSecurityGroup
  id
  name
  location=""
  tags={}
  resources=[]
  dependsOn=[]]

  [@armResource
    id=id
    name=name
    profile=AZURE_VIRTUAL_NETWORK_SECURITY_GROUP_RESOURCE_TYPE
    location=location
    tags=tags
    resources=resources
    dependsOn=dependsOn
  /]
[/#macro]

[#macro createServiceEndpointPolicyDefinition
  id
  name
  description=""
  service=""
  serviceResources=[]
  dependsOn=[]]

  [@armResource
    id=id
    name=name
    profile=AZURE_SERVICE_ENDPOINT_POLICY_DEFINITION_RESOURCE_TYPE
    properties={} +
      attributeIfContent("description", description) +
      attributeIfContent("service", service) +
      attributeIfContent("serviceResources", serviceResources)
    dependsOn=dependsOn
  /]
[/#macro]

[#macro createServiceEndpointPolicy
  id
  name
  location=""
  dependsOn=[]
  tags={}]

  [@armResource 
    id=id
    name=name
    profile=AZURE_SERVICE_ENDPOINT_POLICY_RESOURCE_TYPE
    location=location
    dependsOn=dependsOn
    tags=tags
  /]
[/#macro]

[#function getSubnetDelegation
  id=""
  name=""
  serviceName=""
  actions=[]]

  [#local properties = {} +
    attributeIfContent("id", getReference(AZURE_PROVIDER, {"Id": id, "Name": name})) +
    attributeIfContent("serviceName", serviceName) +
    attributeIfContent("actions", actions)
  ]

  [#return {} +
    attributeIfContent("id", id) + 
    attributeIfContent("name", name) +
    attributeIfContent("properties", properties)
  ]
[/#function]

[#function getSubnetLink
  id=""
  name=""
  linkedResourceType=""
  resourceLink=""]

  [#local properties = {} +
    attributeIfContent("linkedResourceType", linkedResourceType) +
    attributeIfContent("link", resourceLink)
  ]

  [#return {} +
    attributeIfContent("id", getReference(AZURE_PROVIDER, id)) +
    attributeIfContent("name", getReference(AZURE_PROVIDER, {"Id": id, "Name": name}, NAME_ATTRIBUTE_TYPE)!"") +
    attributeIfContent("properties", properties)
  ]
[/#function]

[#function getSubnetServiceEndpoint
  serviceType=""
  locations=[]]

  [#return {} + 
    attributeIfContent("service", serviceType) +
    attributeIfContent("locations", locations)
  ]
[/#function]

[#macro createSubnet
  id
  name
  addressPrefix=""
  addressPrefixes=[]
  networkSecurityGroup={}
  routeTable={}
  natGatewayId=""
  serviceEndpoints=[]
  serviceEndpointPolicies=[]
  resourceNavigationLinks=[]
  serviceAssociationLinks=[]
  delegations=[]
  dependsOn=[]]

  [@armResource
    id=id
    name=name
    profile=AZURE_SUBNET_RESOURCE_TYPE
    properties={} +
      attributeIfContent("addressPrefix", addressPrefix) +
      attributeIfContent("addressPrefixes", addressPrefixes) +
      attributeIfContent("networkSecurityGroup", networkSecurityGroup) +
      attributeIfContent("routeTable", routeTable) +
      attributeIfContent("natGateway", attributeIfContent("id", natGatewayId)) +
      attributeIfContent("serviceEndpoints", serviceEndpoints) +
      attributeIfContent("serviceEndpointPolicies", serviceEndpointPolicies) +
      attributeIfContent("resourceNavigationLinks", resourceNavigationLinks) +
      attributeIfContent("serviceAssociationLinks", serviceAssociationLinks) +
      attributeIfContent("delegations", delegations)
    dependsOn=dependsOn
  /]
[/#macro]

[#macro createVnetPeering
  id
  name
  allowVNetAccess=false
  allowForwardedTraffic=false
  allowGatewayTransit=false
  useRemoteGateways=false
  remoteVirtualNetworkId=""
  remoteAddressSpacePrefixes=[]
  peeringState=""
  dependsOn=[]]

  [@armResource
    id=id
    name=name
    profile=AZURE_VIRTUAL_NETWORK_PEERING_RESOURCE_TYPE
    properties={} +
      attributeIfTrue("allowVNetAccess", allowVNetAccess, allowVNetAccess) +
      attributeIfTrue("allowForwardedTraffic", allowForwardedTraffic, allowForwardedTraffic) +
      attributeIfTrue("allowGatewayTransit", allowGatewayTransit, allowGatewayTransit) +
      attributeIfTrue("useRemoteGateways", useRemoteGateways, useRemoteGateways) +
      attributeIfContent("remoteVirtualNetwork", { "id" : remoteVirtualNetworkId } ) +
      attributeIfContent("remoteAddressSpace", { "addressPrefixes" : remoteAddressSpacePrefixes } ) +
      attributeIfContent("peeringState", peeringState)
    dependsOn=dependsOn
  /]
[/#macro]

[#macro createVNet
  id
  name
  dnsServers=[]
  addressSpacePrefixes=[]
  location=regionId
  dependsOn=[]]

  [@armResource
    id=id
    name=name
    profile=AZURE_VIRTUAL_NETWORK_RESOURCE_TYPE
    location=location
    dependsOn=dependsOn
    properties={} +
      attributeIfContent("addressSpace", {} + 
        attributeIfContent("addressPrefixes", addressSpacePrefixes)
      ) +
      attributeIfContent("dhcpOptions", {} +
        attributeIfContent("dnsServers", dnsServers)
      )
  /]
[/#macro]

[#-- 
  TODO(rossmurr4y): Flow Logs object is not currently supported, though exists when created
  via PowerShell. This is being developed by Microsoft and expected Jan 2020 - will need to revisit
  this implimentation at that time to ensure this object remains correct.
  https://feedback.azure.com/forums/217313-networking/suggestions/37713784-arm-template-support-for-nsg-flow-logs
--]
[#macro createNetworkWatcherFlowLog
  id
  name
  targetResourceId
  storageId
  targetResourceGuid=""
  workspaceId=""
  trafficAnalyticsInterval=""
  retentionPolicyEnabled=false
  retentionDays=""
  formatType=""
  formatVersion=""
  location=""
  dependsOn=[]]

  [#local networkWatcherFlowAnalyticsConfiguration = { "enabled" : true } +
    attributeIfContent("workspaceId", workspaceId) +
    attributeIfContent("trafficAnalyticsInterval", trafficAnalyticsInterval)]

  [#local flowAnalyticsConfiguration = { "networkWatcherFlowAnalyticsConfiguration" : networkWatcherFlowAnalyticsConfiguration }]

  [#local retentionPolicy = {} +
    attributeIfContent("days", retentionDays) +
    attributeIfTrue("enabled", retentionPolicyEnabled, retentionPolicyEnabled)]

  [#local format = {} +
    attributeIfContent("type", formatType) +
    attributeIfContent("version", formatVersion)]

  [@armResource
    id=id
    name=name
    profile=AZURE_NETWORK_WATCHER_RESOURCE_TYPE
    properties={ "enabled" : true } +
      attributeIfContent("targetResourceId", targetResourceId) +
      attributeIfContent("targetResourceGuid", targetResourceGuid) +
      attributeIfContent("storageId", storageId) +
      attributeIfContent("flowAnalyticsConfiguration", flowAnalyticsConfiguration) +
      attributeIfContent("retentionPolicy", retentionPolicy) +
      attributeIfContent("format", format)
    location=location
    dependsOn=dependsOn
  /]
[/#macro]

[#function getPublicIPPrefixIPTag type tag]
  [#return { "ipTagType": tag, "tag": tag }]
[/#function]

[#macro createPublicIPAddressPrefix
  id
  name
  location
  publicIPAddressVersion="IPv4"
  ipTags=[]
  prefixLength=""
  zones=[]]

  [@armResource
    id=id
    name=name
    profile=AZURE_PUBLIC_IP_ADDRESS_PREFIX_RESOURCE_TYPE
    location=location
    sku={"name": "Standard"}
    zones=zones
    properties=
      {
        "publicIPAddressVersion": publicIPAddressVersion
      } +
      attributeIfContent("ipTags", ipTags) +
      numberAttributeIfContent("prefixLength", prefixLength)
  /]

[/#macro]

[#-- specifying no zones "[]" means "Zone Redundant" --]
[#macro createPublicIPAddress
  id
  name
  location
  allocationMethod="Static"
  publicIpAddressVersion="IPv4"
  ipAddress=""
  ipPrefixId=""
  idleTimeoutInMins=""
  dnsNameLabel=""
  dnsFQDN=""
  dnsReverseFQDN=""
  ddosCustomPolicyId=""
  ddosProtectionCoverageType=""
  sku="Standard"
  ipTags=[]
  zones=[]
  outputs={}
  dependsOn=[]]

  [@armResource
    id=id
    name=name
    profile=AZURE_PUBLIC_IP_ADDRESS_RESOURCE_TYPE
    location=location
    sku={ "name" : sku }
    zones=zones
    dependsOn=dependsOn
    properties=
      {
        "publicIPAllocationMethod" : allocationMethod,
        "publicIPAddressVersion" : publicIpAddressVersion
      } +
      attributeIfContent(
        "dnsSettings", 
        {} + 
        attributeIfContent("domainNameLabel", dnsNameLabel) +
        attributeIfContent("fqdn", dnsFQDN) +
        attributeIfContent("reverseFqdn", dnsReverseFQDN)
      ) +
      attributeIfContent(
        "ddosSettings",
        {} +
        attributeIfContent(
          "ddosCustomPolicy",
          {} +
          attributeIfContent("id", ddosCustomPolicyId)
        ) +
        attributeIfContent("protectionCoverage", ddosProtectionCoverageType)
      ) +
      attributeIfContent("ipTags", ipTags) +
      attributeIfContent("ipAddress", ipAddress) +
      attributeIfContent(
        "publicIPPrefix", 
        {} +
        attributeIfContent("id", ipPrefixId)
      ) +
      attributeIfContent("idleTimeoutInMinutes", idleTimeoutInMins?has_content?then(idleTimeoutInMins?number, ""))
  /]

[/#macro]

[#function getIPConfiguration
  name
  subnetId
  primaryAddress=false
  publicIpAddressId=""
  publicIPAddressConfigurationName=""
  publicIPAddressConfigurationIdleTimeout=""
  publicIPAddressConfigurationIPTags=[]
  publicIPAddressConfigurationIPVersion=""
  publicIPAddressConfigurationIPPrefixId=""
  privateIpAddress=""
  privateIpAllocationMethod="Dynamic"
  privateIpAddressVersion="IPv4"
  vnetTapIds=[]
  appGatewayBackendAddressPoolIds=[]
  loadBalancerBackendAddressPoolIds=[]
  loadBalancerInboundNatRuleIds=[]
  applicationSecurityGroupIds=[]]

  [#local vnetTapReferences = []]
  [#list vnetTapIds as id]
    [#local vnetTapReferences += [{ "id" : id }]]
  [/#list]

  [#local appGWBackendAddressPoolReferences = []]
  [#list appGatewayBackendAddressPoolIds as id]
    [#local appGWBackendAddressPoolReferences += [{ "id" : id }]]
  [/#list]

  [#local loadBalancerBackendAddressPoolReferences = []]
  [#list loadBalancerBackendAddressPoolIds as id]
    [#local loadBalancerBackendAddressPoolReferences += [{ "id" : id }]]
  [/#list]

  [#local loadBalancerInboundNatRulesReferences = []]
  [#list loadBalancerInboundNatRuleIds as id]
    [#local loadBalancerInboundNatRulesReferences += [{ "id" : id }]]
  [/#list]

  [#local applicationSecurityGroupReferences = []]
  [#list applicationSecurityGroupIds as id]
    [#local applicationSecurityGroupReferences += [{ "id" : id }]]
  [/#list]
  
  [#return
    {
      "name" : name,
      "properties" : {
        "subnet" : {
          "id" : subnetId
        } +
        attributeIfContent("privateIPAllocationMethod", privateIpAllocationMethod) +
        attributeIfContent("privateIPAddressVersion", privateIpAddressVersion)
      } +
      attributeIfContent("virtualNetworkTaps", vnetTapReferences) + 
      attributeIfContent("applicationGatewayBackendAddressPools", appGWBackendAddressPoolReferences) +
      attributeIfContent("loadBalancerBackendAddressPools", loadBalancerBackendAddressPoolReferences) +
      attributeIfContent("loadBalancerInboundNatRules", loadBalancerInboundNatRulesReferences) +
      attributeIfContent("privateIPAddress", privateIpAddress) +
      attributeIfTrue("primary", primaryAddress, primaryAddress) +
      attributeIfContent(
        "publicIPAddress", {} +
        attributeIfContent("id", publicIpAddressId)
      ) +
      attributeIfContent(
        "publicIPAddressConfiguration",
          attributeIfContent("name", publicIPAddressConfigurationName) +
          attributeIfContent("properties", {} +
            attributeIfContent("idleTimeoutInMinutes", publicIPAddressConfigurationIdleTimeout) +
            attributeIfContent("ipTags", publicIPAddressConfigurationIPTags) +
            attributeIfContent("publicIPAddressVersion", publicIPAddressConfigurationIPVersion) +
            attributeIfContent("publicIPPrefix", {} + 
              attributeIfContent("id", publicIPAddressConfigurationIPPrefixId)
            )
          )
      ) +
      attributeIfContent("applicationSecurityGroups", applicationSecurityGroupReferences)
    }
  ]

[/#function]

[#macro createNetworkInterface
  id
  name
  location
  nsgId
  ipConfigurations=[]
  dnsSettings=[]
  enableAcceleratedNetworking=false
  enableIPForwarding=false
  outputs={}
  dependsOn=[]]

  [@armResource
    id=id
    name=name
    profile=AZURE_NETWORK_INTERFACE_RESOURCE_TYPE
    location=location
    dependsOn=dependsOn
    properties=
      {
        "networkSecurityGroup" : {
          "id" : nsgId
        }
      } +
      attributeIfContent("ipConfigurations", ipConfigurations) +
      attributeIfContent("dnsSettings", dnsSettings) +
      attributeIfTrue("enableAcceleratedNetworking", enableAcceleratedNetworking, enableAcceleratedNetworking) +
      attributeIfTrue("enableIPForwarding", enableIPForwarding, enableIPForwarding)
  /]

[/#macro]

[#-- Utility Network functions --]
[#function getSubnet tier networkResources asReference=false]
  [#local subnet = networkResources.subnets[tier.Id]["subnet"]]

  [#if asReference]
    [#return subnet.Reference]
  [#else]
    [#return subnet]
  [/#if]
[/#function]
