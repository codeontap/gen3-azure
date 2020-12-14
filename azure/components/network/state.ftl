[#ftl]

[#macro azure_network_arm_state occurrence parent={}]

  [#local core = occurrence.Core]
  [#local solution = occurrence.Configuration.Solution]

  [#local vnetId = formatVirtualNetworkId(core.Id)]
  [#local vnetName = core.ShortTypedFullName]
  [#local nsgId = formatDependentNetworkSecurityGroupId(vnetId)]
  [#local nsgName = formatName(vnetName, AZURE_VIRTUAL_NETWORK_SECURITY_GROUP_RESOURCE_TYPE)]

  [#local nsgFlowLogEnabled = isPresent(segmentObject.Operations)?then(
      isPresent(environmentObject.Operations.FlowLogs) ||
      isPresent(segmentObject.Operations.FlowLogs) ||
      solution.Logging.EnableFlowLogs,
      isPresent(environmentObject.Operations.FlowLogs) ||
      solution.Logging.EnableFlowLogs
  )]

  [#local networkCIDR = isPresent(network.CIDR)?then(
    network.CIDR.Address + "/" + network.CIDR.Mask,
    solution.Address.CIDR )]

  [#local networkAddress = networkCIDR?split("/")[0]]
  [#local networkMask = (networkCIDR?split("/")[1])?number]

  [#local subnetCIDRMask = getSubnetMaskFromSizes(
    networkCIDR,
    network.Tiers.Order?size)]

  [#local subnetCIDRs = getSubnetsFromNetwork(
    networkCIDR,
    subnetCIDRMask)]

  [#-- Define subnets /w routeTableRoutes --]
  [#local subnets = {}]
  [#local routeTableRoutes = {}]
  [#list segmentObject.Network.Tiers.Order as tierId]

    [#local networkTier = getTier(tierId) ]
    [#-- Filter out to only valid tiers --]
    [#if ! (networkTier?has_content &&
            networkTier.Network.Enabled &&
            networkTier.Network.Link.Tier == core.Tier.Id &&
            networkTier.Network.Link.Component == core.Component.Id &&
            (networkTier.Network.Link.Version!core.Version.Id) == core.Version.Id &&
            (networkTier.Network.Link.Instance!core.Instance.Id) == core.Instance.Id)]
      [#continue]
    [/#if]

    [#local subnetId = formatDependentResourceId(AZURE_SUBNET_RESOURCE_TYPE, networkTier.Id)]
    [#local resourceProfile = getAzureResourceProfile(AZURE_SUBNET_RESOURCE_TYPE)]

    [#local subnets = mergeObjects(
      subnets,
      {
        networkTier.Id : {
          "subnet": {
            "Id": subnetId,
            "Name": networkTier.Name,
            "Address": subnetCIDRs[tierId?index],
            "Type": AZURE_SUBNET_RESOURCE_TYPE,
            "Reference" : getReference(subnetId, networkTier.Name)
          }
        }
      }
    )]

    [#local routeTableRoutes = mergeObjects(
      routeTableRoutes,
      {
        networkTier.Id : {
          "routeTableRoute" : {
            "Id" : formatDependentResourceId(AZURE_ROUTE_TABLE_ROUTE_RESOURCE_TYPE, networkTier.Name),
            "Name" : formatName(AZURE_ROUTE_TABLE_ROUTE_RESOURCE_TYPE, networkTier.Id),
            "Type" : AZURE_ROUTE_TABLE_ROUTE_RESOURCE_TYPE
          }
        }
      }
    )]
  [/#list]

  [#local elbNSG = {}]
  [#if (subnets["elb"]!{})?has_content]
    [#local elbNsgId = formatDependentNetworkSecurityGroupId(vnetId, "elb")]
    [#local elbNsgName = formatName(nsgName, "elb")]
    [#local elbNSG = 
      {
        "Id" : elbNsgId,
        "Name" : elbNsgName,
        "Type" : AZURE_VIRTUAL_NETWORK_SECURITY_GROUP_RESOURCE_TYPE,
        "Reference" : getReference(elbNsgId, elbNsgName)
      }]
  [/#if]

  [#assign componentState =
    {
      "Resources" : {
        "vnet" : {
          "Id" : vnetId,
          "Name" : vnetName,
          "Address" : networkAddress + "/" + networkMask,
          "Type" : AZURE_VIRTUAL_NETWORK_RESOURCE_TYPE
        },
        "subnets" : subnets,
        "routeTableRoutes" : routeTableRoutes,
        "networkSecurityGroup" : {
          "Id" : nsgId,
          "Name" : nsgName,
          "Type" : AZURE_VIRTUAL_NETWORK_SECURITY_GROUP_RESOURCE_TYPE,
          "Reference" : getReference(nsgId, nsgName)
        }
      } +
      attributeIfContent("elbNSG", elbNSG) +
      attributeIfTrue(
        "flowlogs",
        nsgFlowLogEnabled,
        {
          "networkWatcherFlowlog" : {
            "Id" : formatDependentNetworkWatcherId(nsgId),
            "Name" : formatName(vnetName, AZURE_NETWORK_WATCHER_RESOURCE_TYPE),
            "Type" : AZURE_NETWORK_WATCHER_RESOURCE_TYPE
          }
        }
      ),
      "Attributes" : {},
      "Roles" : {
        "Inbound" : {},
        "Outbound" : {}
      }
    }
  ]
[/#macro]

[#macro azure_networkroute_arm_state occurrence parent={}]
  [#local core = occurrence.Core]
  [#local solution = occurrence.Configuration.Solution]

  [#--
    The routeTable known as "default" refers to the Microsoft managed routeTable.
   --]
  [#if ! (core.SubComponent.Name == "default") ]
    [#assign componentState =
      {
        "Resources" : {
          "routeTable" : {
            "Id" : formatDependentResourceId(AZURE_ROUTE_TABLE_RESOURCE_TYPE, core.Id),
            "Name" : formatName(AZURE_ROUTE_TABLE_RESOURCE_TYPE, core.ShortName),
            "Type" : AZURE_ROUTE_TABLE_RESOURCE_TYPE
          }
        },
        "Attributes" : {},
        "Roles" : {
            "Inbound" : {},
            "Outbound" : {}
        }
      }
    ]
  [#else]
    [#assign componentState =
      {
        "Resources" : {},
        "Attributes" : {},
        "Roles" : {
            "Inbound" : {},
            "Outbound" : {}
        }
      }
    ]
  [/#if]
[/#macro]

[#-- As a subcomponent, this NetworkACL is using a NetworkSecurityGroup
resource. It remains "networkacl" in name to ensure there is no clash
with any future networkSecurityGroup components. When referring to
the Resource alone, it will remain NetworkSecurityGroup for clarity
as Azure does not have NetworkACLs.--]
[#macro azure_networkacl_arm_state occurrence parent={}]

  [#local core = occurrence.Core]
  [#local solution = occurrence.Configuration.Solution]

  [#assign componentState =
    {
      "Resources" : {},
      "Attributes" : {},
      "Roles" : {
        "Inbound" : {},
        "Outbound" : {}
      }
    }
  ]
[/#macro]
