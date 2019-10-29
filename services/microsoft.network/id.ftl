[#ftl]

[#assign AZURE_APPLICATION_SECURITY_GROUP_RESOURCE_TYPE = "applicationSecurityGroup"]
[#assign AZURE_ROUTE_TABLE_RESOURCE_TYPE = "routeTable"]
[#assign AZURE_ROUTE_TABLE_ROUTE_RESOURCE_TYPE = "route"]
[#assign AZURE_SERVICE_ENDPOINT_POLICY_RESOURCE_TYPE = "serviceEndpointPolicy"]
[#assign AZURE_SERVICE_ENDPOINT_POLICY_DEFINITION_RESOURCE_TYPE = "serviceEndpointPolicyDefinition"]
[#assign AZURE_SUBNET_RESOURCE_TYPE = "subnet"]
[#assign AZURE_VIRTUAL_NETWORK_RESOURCE_TYPE = "virtualNetwork"]
[#assign AZURE_VIRTUAL_NETWORK_PEERING_RESOURCE_TYPE = "virtualNetworkPeering"]
[#assign AZURE_VIRTUAL_NETWORK_SECURITY_GROUP_RESOURCE_TYPE = "networkSecurityGroup"]
[#assign AZURE_VIRTUAL_NETWORK_SECURITY_GROUP_SECURITY_RULE_RESOURCE_TYPE = "securityRule"]
[#assign AZURE_NETWORK_WATCHER_RESOURCE_TYPE = "networkWatcher"]

[#function formatDependentNetworkWatcherId resourceId extensions...]
  [#return formatDependentResourceId(
    AZURE_NETWORK_WATCHER_RESOURCE_TYPE
    resourceId,
    extensions)]
[/#function]

[#function formatDependentApplicationSecurityGroupId resourceId extensions...]
  [#return formatDependentResourceId(
    AZURE_APPLICATION_SECURITY_GROUP_RESOURCE_TYPE
    resourceId,
    extensions)]
[/#function]

[#function formatDependentRouteTableId resourceId extensions...]
  [#return formatDependentResourceId(
    AZURE_ROUTE_TABLE_RESOURCE_TYPE,
    resourceId,
    extensions)]
[/#function]
[#function formatDependentRouteTableRouteId resourceId extensions...]
  [#return formatDependentResourceId(
    AZURE_ROUTE_TABLE_ROUTE_RESOURCE_TYPE,
    resourceId,
    extensions)]
[/#function]

[#function formatDependentServiceEndpointPolicyId resourceId extensions...]
  [#return formatDependentResourceId(
    AZURE_SERVICE_ENDPOINT_POLICY_RESOURCE_TYPE,
    resourceId,
    extensions)]
[/#function]

[#function formatDependentServiceEndpointPolicyDefinitionId resourceId extensions...]
  [#return formatDependentResourceId(
    AZURE_SERVICE_ENDPOINT_POLICY_DEFINITION_RESOURCE_TYPE,
    resourceId,
    extensions)]
[/#function]

[#function formatDependentSubnetId resourceId extensions...]
  [#return formatDependentResourceId(
    AZURE_SUBNET_RESOURCE_TYPE,
    resourceId,
    extensions)]
[/#function]

[#function formatVirtualNetworkId ids...]
  [#return formatResourceId(
    AZURE_VIRTUAL_NETWORK_RESOURCE_TYPE,
    ids)]
[/#function]

[#function formatDependentVirtualNetworkPeeringId resourceId extensions...]
  [#return formatDependentResourceId(
    AZURE_VIRTUAL_NETWORK_PEERING_RESOURCE_TYPE,
    resourceId,
    extensions)]
[/#function]

[#function formatDependentNetworkSecurityGroupId resourceId extensions...]
  [#return formatDependentResourceId(
    AZURE_VIRTUAL_NETWORK_SECURITY_GROUP_RESOURCE_TYPE,
    resourceId,
    extensions)]
[/#function]

[#function formatNetworkSecurityGroupId ids...]
  [#return formatResourceId(
    AZURE_VIRTUAL_NETWORK_SECURITY_GROUP_RESOURCE_TYPE,
    ids)]
[/#function]

[#function formatDependentSecurityRuleId resourceId extensions...]
  [#return formatDependentResourceId(
    AZURE_VIRTUAL_NETWORK_SECURITY_GROUP_SECURITY_RULE_RESOURCE_TYPE,
    resourceId,
    extensions)]
[/#function]