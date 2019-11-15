[#ftl]

[#assign networkResourceProfiles = {
  AZURE_APPLICATION_SECURITY_GROUP_RESOURCE_TYPE : {
    "apiVersion" : "2019-04-01",
    "type" : "Microsoft.Network/applicationSecurityGroups"
  },
  AZURE_ROUTE_TABLE_RESOURCE_TYPE : {
    "apiVersion" : "2019-02-01",
    "type" : "Microsoft.Network/routeTables"
  },
  AZURE_ROUTE_TABLE_ROUTE_RESOURCE_TYPE : {
    "apiVersion" : "2019-02-01",
    "type" : "Microsoft.Network/routeTables/routes"
  },
  AZURE_SERVICE_ENDPOINT_POLICY_RESOURCE_TYPE : {
    "apiVersion" : "2019-02-01",
    "type" : "Microsoft.Network/serviceEndpointPolicies"
  },
  AZURE_SERVICE_ENDPOINT_POLICY_DEFINITION_RESOURCE_TYPE : {
    "apiVersion" : "2019-02-01",
    "type" : "Microsoft.Network/serviceEndpointPolicies/serviceEndpointPolicyDefinitions"
  },
  AZURE_SUBNET_RESOURCE_TYPE : {
    "apiVersion" : "2019-02-01",
    "type" : "Microsoft.Network/virtualNetworks/subnets"
  },
  AZURE_VIRTUAL_NETWORK_RESOURCE_TYPE : {
    "apiVersion" : "2019-02-01",
    "type" : "Microsoft.Network/virtualNetworks"
  },
  AZURE_VIRTUAL_NETWORK_PEERING_RESOURCE_TYPE : {
    "apiVersion" : "2019-02-01",
    "type" : "Microsoft.Network/virtualNetworks/virtualNetworkPeerings"
  },
  AZURE_VIRTUAL_NETWORK_SECURITY_GROUP_RESOURCE_TYPE : {
    "apiVersion" : "2019-02-01",
    "type" : "Microsoft.Network/networkSecurityGroups"
  },
  AZURE_VIRTUAL_NETWORK_SECURITY_GROUP_SECURITY_RULE_RESOURCE_TYPE : {
    "apiVersion" : "2019-04-01",
    "type" : "Microsoft.Network/networkSecurityGroups/securityRules"
  },
  AZURE_NETWORK_WATCHER_RESOURCE_TYPE : {
    "apiVersion" : "2019-04-01",
    "type" : "Microsoft.Network/networkWatchers"
  }
}]

[#list networkResourceProfiles as resource,attributes]
  [@addResourceProfile
    service=AZURE_NETWORK_SERVICE
    resource=resource
    profile=
      {
        "apiVersion" : attributes.apiVersion,
        "type" : attributes.type
      }
  /]
[/#list]

[#assign VIRTUAL_NETWORK_OUTPUT_MAPPINGS = 
  {
    REFERENCE_ATTRIBUTE_TYPE : {
      "Property" : "id"
    }
  }
]

[#assign SUBNET_OUTPUT_MAPPINGS =
  {
    REFERENCE_ATTRIBUTE_TYPE : {
      "Property" : "id"
    }
  }
]

[@addOutputMapping 
  provider=AZURE_PROVIDER
  resourceType=AZURE_VIRTUAL_NETWORK_RESOURCE_TYPE
  mappings=VIRTUAL_NETWORK_OUTPUT_MAPPINGS
/]

[@addOutputMapping 
  provider=AZURE_PROVIDER
  resourceType=AZURE_SUBNET_RESOURCE_TYPE
  mappings=SUBNET_OUTPUT_MAPPINGS
/]

[#macro createApplicationSecurityGroup id name location tags={}]
  [@armResource
    id=id
    name=name
    profile=AZURE_APPLICATION_SECURITY_GROUP_RESOURCE_TYPE
    location=location
    tags=tags
  /]
[/#macro]

[#macro createNetworkSecurityGroupSecurityRule
  id
  name
  protocol
  access
  direction
  sourceAddressPrefix=""
  sourceAddressPrefixes=[]
  sourcePortRange=""
  sourcePortRanges=[]
  sourceApplicationSecurityGroups=[]
  destinationPortRange=""
  destinationPortRanges=[]
  destinationAddressPrefix=""
  destinationAddressPrefixes=""
  destinationApplicationSecurityGroups=[]
  description=""
  priority=""
  tags={}
  outputs={}
  dependsOn=[]]

  [@armResource
    id=id
    name=name
    profile=AZURE_VIRTUAL_NETWORK_SECURITY_GROUP_SECURITY_RULE_RESOURCE_TYPE
    dependsOn=dependsOn
    properties=  
      {
        "access" : access,
        "direction" : direction,
        "protocol" : protocol
      } +
      attributeIfContent("sourceAddressPrefix", sourceAddressPrefix) +
      attributeIfContent("sourceAddressPrefixes", sourceAddressPrefixes) +
      attributeIfContent("sourcePortRange", sourcePortRange) +
      attributeIfContent("sourcePortRanges", sourcePortRanges) +
      attributeIfContent("sourceApplicationSecurityGroups", sourceApplicationSecurityGroups) +
      attributeIfContent("destinationPortRange", destinationPortRange) +
      attributeIfContent("destinationPortRanges", destinationPortRanges) +
      attributeIfContent("destinationAddressPrefix", destinationAddressPrefix) +
      attributeIfContent("destinationAddressPrefixes", destinationAddressPrefixes) +
      attributeIfContent("destinationApplicationSecurityGroups", destinationApplicationSecurityGroups) +
      attributeIfContent("description", description) +
      attributeIfContent("priority", priority)
    tags=tags
    outputs=outputs
  /]
  
[/#macro]

[#macro createRouteTableRoute
  id
  name
  nextHopType 
  addressPrefix="" 
  nextHopIpAddress=""
  dependsOn=[]
  outputs={}
  tags={}]

  [@armResource
    id=id
    name=name
    profile=AZURE_ROUTE_TABLE_ROUTE_RESOURCE_TYPE
    properties={ "nextHopType" : nextHopType } + 
      attributeIfContent("addressPrefix", addressPrefix) +
      attributeIfContent("nextHopIpAddress", nextHopIpAddress)
    dependsOn=dependsOn
    outputs=outputs
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
  dependsOn=[]
  outputs={}]

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
    outputs=outputs
  /]

[/#macro]

[#macro createNetworkSecurityGroup
  id
  name
  location=""
  tags={}
  resources=[]
  dependsOn=[]
  outputs={}]

  [@armResource
    id=id
    name=name
    profile=AZURE_VIRTUAL_NETWORK_SECURITY_GROUP_RESOURCE_TYPE
    location=location
    tags=tags
    resources=resources
    dependsOn=dependsOn
    outputs=outputs
  /]
[/#macro]

[#macro createServiceEndpointPolicyDefinition
  id
  name
  description=""
  service=""
  serviceResources=[]
  dependsOn=[]
  outputs={}]

  [@armResource
    id=id
    name=name
    profile=AZURE_SERVICE_ENDPOINT_POLICY_DEFINITION_RESOURCE_TYPE
    properties={} +
      attributeIfContent("description", description) +
      attributeIfContent("service", service) +
      attributeIfContent("serviceResources", serviceResources)
    dependsOn=dependsOn
    outputs=outputs
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
    attributeIfContent("id", getReference(id)) +
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
  resourceName=""
  linkedResourceType=""
  resourceLink=""]

  [#local properties = {} +
    attributeIfContent("linkedResourceType", linkedResourceType) +
    attributeIfContent("link", resourceLink)
  ]

  [#return {} +
    attributeIfContent("id", getReference(id)) +
    attributeIfContent("name", getReference(resourceName)) +
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
  delegations=[]]

  [@armResource
    id=id
    name=name
    profile=AZURE_SUBNET_RESOURCE_TYPE
    properties={} +
      attributeIfContent("addressPrefix", addressPrefix) +
      attributeIfContent("addressPrefixes", addressPrefixes) +
      attributeIfContent("networkSecurityGroup", networkSecurityGroup) +
      attributeIfContent("routeTable", routeTable) +
      attributeIfContent("natGateway", { "id" : natGatewayId } ) +
      attributeIfContent("serviceEndpoints", serviceEndpoints) +
      attributeIfContent("serviceEndpointPolicies", serviceEndpointPolicies) +
      attributeIfContent("resourceNavigationLinks", resourceNavigationLinks) +
      attributeIfContent("serviceAssociationLinks", serviceAssociationLinks) +
      attributeIfContent("delegations", delegations)
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
  outputs={}
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
    outputs=outputs
    dependsOn=dependsOn
  /]
[/#macro]

[#macro createVNet
  id
  name
  dnsServers=[]
  addressSpacePrefixes=[]
  location=regionId
  outputs={}
  dependsOn=[]]

  [@armResource
    id=id
    name=name
    profile=AZURE_VIRTUAL_NETWORK_RESOURCE_TYPE
    location=location
    outputs=outputs
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
  outputs={}
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
      attributeIfContent("targetResourceId", getReference(targetResourceId)) +
      attributeIfContent("targetResourceGuid", targetResourceGuid) +
      attributeIfContent("storageId", storageId) +
      attributeIfContent("flowAnalyticsConfiguration", flowAnalyticsConfiguration) +
      attributeIfContent("retentionPolicy", retentionPolicy) +
      attributeIfContent("format", format)
    location=location
    outputs=outputs
    dependsOn=dependsOn
  /]
[/#macro]