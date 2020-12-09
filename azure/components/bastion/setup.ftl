[#ftl]
[#macro azure_bastion_arm_deployment_generationcontract occurrence]
  [@addDefaultGenerationContract subsets=[ "template", "parameters"] /]
[/#macro]

[#macro azure_bastion_arm_deployment occurrence]

  [@debug message="Entering Bastion Setup" context=occurrence enabled=false /]
  [#local core = occurrence.Core]
  [#local solution = occurrence.Configuration.Solution]
  [#local resources = occurrence.State.Resources]
  [#local autoScaleConfig = solution.AutoScaling]

  [#-- Network Lookups & Links --]
  [#-- As full subnet name is vnet/subnet, retrieve both & format --]
  [#local occurrenceNetwork = getOccurrenceNetwork(occurrence)]
  [#local networkLink = occurrenceNetwork.Link!{} ]
  [#local networkLinkTarget = getLinkTarget(occurrence, networkLink, false) ]

  [#if ! networkLinkTarget?has_content ]
      [@fatal message="Network could not be found" context=networkLink /]
      [#return]
  [/#if]

  [#local networkResources = networkLinkTarget.State.Resources ]
  [#local networkVnetResource = networkResources["vnet"]]
  [#local subnetResource = getSubnet(core.Tier, networkResources)]
  [#local subnetName = formatAzureResourceName(
    subnetResource.Name,
    getResourceType(subnetResource.Id),
    networkVnetResource.Name
  )]
  [#local subnetReference = getReference(AZURE_PROVIDER, subnetResource.Id)]

  [#-- Baseline Component Lookup --]
  [#local baselineLinks = getBaselineLinks(occurrence, ["SSHKey"], false, false)]
  [#local baselineAttributes = baselineLinks["SSHKey"].State.Attributes]
  [#local baselineResources = baselineLinks["SSHKey"].State.Resources]
  [#local sshKeyPairResourceId = getReference(AZURE_PROVIDER, baselineResources["vmKeyPair"].Id)]
  [#local sshKey = baselineResources["vmKeyPair"]]
  [#local sshPublicKeyParameterName = sshKey.Name + "PublicKey"]

  [#-- Resources                                        --]
  [#-- Add Reference Attribute to all for simple lookup --]
  [#local prefix = resources["publicIPPrefix"]]
  [#local publicIP = resources["publicIP"]]
  [#local nic = resources["networkInterface"]]
  [#local nsg = networkResources["networkSecurityGroup"]]
  [#local scaleSet = resources["scaleSet"]]
  [#local autoScalePolicy = resources["autoScalePolicy"]]

  [#-- Public IP --]
  [@createPublicIPAddressPrefix
    id=prefix.Id
    name=prefix.Name
    location=regionId
    prefixLength=28
  /]
  [@createPublicIPAddress
    id=publicIP.Id
    name=publicIP.Name
    location=regionId
    ipPrefixId=prefix.Reference
    dependsOn=
      [
        prefix.Reference
      ]
  /]

  [#-- NIC --]
  [#local nicIpConfiguration = getIPConfiguration(
    "default",
    subnetReference,
    true,
    publicIP.Reference
  )]

  [@createNetworkInterface
    id=nic.Id
    name=nic.Name
    location=regionId
    nsgId=nsg.Reference
    ipConfigurations=[nicIpConfiguration]
    dependsOn=
      [
        publicIP.Reference
      ]
  /]

  [#-- VM Scale Set --]
  [#local vmssProcessorProfile = processors[solution.Profiles.Processor]]
  [#local vmssProcessorType = vmssProcessorProfile[core.Type]]
  [#local vmssProcessor = vmssProcessorType.Processor]
  [#local vmssProcessorTier = vmssProcessor?split("_")[0]]
  [#local vmssVMImageProfile = getVMImageProfile(occurrence, core.Type)]
  [#local vmssVMAdminName = BASTION_COMPONENT_TYPE]

  [#if deploymentSubsetRequired("parameters", true)]

      [@createKeyVaultParameterLookup
        secretName=sshPublicKeyParameterName
        vaultId=baselineAttributes["KEYVAULT_ID"]
      /]

  [/#if]
  [#local vmssVMOSConfig = getVirtualMachineProfileLinuxConfig(
    [
      getVirtualMachineProfileLinuxConfigPublicKey(
      "/home/" + vmssVMAdminName + "/.ssh/authorized_keys",
        getParameterReference(sshPublicKeyParameterName)
      )
    ],
    true
  )]

  [#-- IP Config that references the existing NIC and IP Prefix --]
  [#local nicIPReference = getIPConfiguration(
    "default",
    subnetReference,
    true,
    "",
    "default",
    15,
    [],
    "IPv4",
    prefix.Reference
     "", "", ""
  )]

  [#local vmssVMNICConfig = getVirtualMachineNetworkProfileNICConfig(
    nic.Reference,
    nic.Name,
    nicIPReference.properties.primary,
    [nicIPReference]
  )]

  [#local vmssVMNetworkProfile = getVirtualMachineNetworkProfile([vmssVMNICConfig])]
  [#local vmssVMSkuProfile = getSkuProfile(occurrence, core.Type)]

  [#local vmssVMProfile = getVirtualMachineProfile(
    "Standard_LRS",
    vmssVMImageProfile.Publisher,
    vmssVMImageProfile.Offering,
    vmssVMImageProfile.Image,
    vmssVMNetworkProfile,
    vmssVMOSConfig,
    core.Type,
    vmssVMAdminName
  )]

  [@createVMScaleSet
    id=scaleSet.Id
    identity={"type": "SystemAssigned"}
    name=scaleSet.Name
    location=regionId
    skuName=vmssVMSkuProfile.Name
    skuTier=vmssVMSkuProfile.Tier
    skuCapacity=vmssVMSkuProfile.Capacity
    vmProfile=vmssVMProfile
    dependsOn=
      [
        nic.Reference
      ]
  /]


  [#-- AutoScale Policy --]
  [#if autoScaleConfig.Enabled]

    [#-- TODO: rossmurr4y
    Add autoscaling configuration for the VMSS.

    [#local autoScaleTargetId = autoScalePolicy.Reference]

    [#local autoScaleRule = getAutoScaleRule()]

    [#local autoScaleProfile = getAutoScaleProfile(
      "scale-to-zero-when-unused",
      autoScaleConfig.MinUpdateInstances,
      "1",
      autoScaleConfig.MinUpdateInstances,
      [autoScaleRule])]

    [@createAutoscaleSettings
      id=autoScalePolicy.Id
      name=autoScalePolicy.Name
      location=regionId
      targetId=autoScaleTargetId
      profiles=[autoScaleProfile]
      enabled=autoScaleConfig.Enabled
      dependsOn=
        [
          autoScaleTargetId
        ]
    /]
    --]
  [/#if]

  [#-- NSG Rule - Allow SSH Inbound --]

[/#macro]
