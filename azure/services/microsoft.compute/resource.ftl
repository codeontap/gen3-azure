[#ftl]

[@addResourceProfile
  service=AZURE_VIRTUALMACHINE_SERVICE
  resource=AZURE_VIRTUALMACHINE_SCALESET_RESOURCE_TYPE
  profile=
    {
      "apiVersion" : "2019-03-01",
      "type" : "Microsoft.Compute/virtualMachineScaleSets",
      "outputMappings" : {
        REFERENCE_ATTRIBUTE_TYPE : {
          "Property" : "id"
        },
        NAME_ATTRIBUTE_TYPE : {
          "Property" : "name"
        }
      }
    }
/]

[@addResourceProfile
  service=AZURE_VIRTUALMACHINE_SERVICE
  resource=AZURE_VIRTUALMACHINE_SCALESET_EXTENSION_RESOURCE_TYPE
  profile=
    {
      "apiVersion" : "2019-12-01",
      "type" : "Microsoft.Compute/virtualMachineScaleSets/extensions",
      "outputMappings" : {}
    }
/]

[#function getVirtualMachineProfileLinuxConfigPublicKey
  path=""
  data=""]

  [#return
    {} +
    attributeIfContent("path", path) +
    attributeIfContent("keyData", data)
  ]

[/#function]

[#function getVirtualMachineProfileLinuxConfig
  publicKeys
  disablePasswordAuth=true]

  [#return
    {
      "ssh" : {
        "publicKeys" : publicKeys
      }
    } +
    attributeIfTrue("disablePasswordAuthentication", disablePasswordAuth, disablePasswordAuth)
  ]

[/#function]

[#function getVirtualMachineProfileWindowsConfig
  autoUpdatesEnabled=false
  timeZone=""
  unattendContent=[]
  winRM={}]

  [#return
    {} + 
    attributeIfTrue("enableAutomaticUpdates", autoUpdatesEnabled, autoUpdatesEnabled) +
    attributeIfContent("timeZone", timeZone) +
    attributeIfContent("additionalUnattendContent", unattendContent) +
    attributeIfContent("winRM", winRM)
  ]

[/#function]

[#function getVirtualMachineNetworkProfileNICConfig
  id
  name
  primary=false
  ipConfigurations=[]]

  [#return 
    {
      "id": id,
      "name": name,
      "properties" : {
        "primary" : primary,
        "ipConfigurations" : ipConfigurations
      }
    }
  ]

[/#function]

[#function getVirtualMachineNetworkProfile 
  networkInterfaceConfigurations=[]
  healthProbe={}]
  [#return
    {} +
    attributeIfContent("networkInterfaceConfigurations", networkInterfaceConfigurations) +
    attributeIfContent("healthProbe", healthProbe)]
[/#function]

[#function getVirtualMachineProfile
  storageAccountType
  imagePublisher
  imageOffer
  image
  nicConfigurations
  linuxConfiguration={}
  vmNamePrefix=""
  adminName=""
  windowsConfiguration={}
  priority="Regular"
  imageVersion="latest"
  licenseType=""]

  [#return 
    {
      "osProfile" : {} +
        attributeIfContent("computerNamePrefix", vmNamePrefix) +
        attributeIfContent("adminUsername", adminName) +
        attributeIfContent("linuxConfiguration", linuxConfiguration) +
        attributeIfContent("windowsConfiguration", windowsConfiguration),
      "storageProfile" : {
        "osDisk" : {
          "createOption" : "FromImage",
          "managedDisk" : {  
          } +
          attributeIfContent("storageAccountType", storageAccountType)
        },
        "imageReference" : {
          "publisher" : imagePublisher,
          "offer" : imageOffer,
          "sku" : image,
          "version" : imageVersion
        }
      },
      "networkProfile" : nicConfigurations,
      "priority" : priority
    } +
    attributeIfContent("licenseType", licenseType)
  ]

[/#function]

[#macro createVMScaleSet
  id
  name
  location
  skuName
  skuTier
  skuCapacity
  vmProfile
  vmUpgradeMode="Manual"
  identity={}
  zones=[]
  dependsOn={}]

  [@armResource
    id=id
    name=name
    profile=AZURE_VIRTUALMACHINE_SCALESET_RESOURCE_TYPE
    location=location
    sku=
      {
        "name" : skuName,
        "tier" : skuTier,
        "capacity" : skuCapacity
      }
    identity=identity
    dependsOn=dependsOn
    zones=zones
    properties=
      { 
        "upgradePolicy" : {
          "mode" : vmUpgradeMode
        },
        "virtualMachineProfile" : vmProfile 
      }
  /]

[/#macro]

[#macro createVMScaleSetExtension
  id
  name
  publisher=""
  type=""
  typeHandlerVersion=""
  autoUpgradeMinorVersion=false
  settings={}
  protectedSettings={}
  provisionAfterExtensions=[]
  dependsOn=[]]

  [#-- Settings should be listed even when empty. --]

  [@armResource
    id=id
    name=name
    profile=AZURE_VIRTUALMACHINE_SCALESET_EXTENSION_RESOURCE_TYPE
    dependsOn=dependsOn
    properties={
      "settings" : settings
    } +
      attributeIfContent("publisher", publisher) +
      attributeIfContent("type", type) +
      attributeIfContent("typeHandlerVersion", typeHandlerVersion) +
      attributeIfContent("autoUpgradeMinorVersion", autoUpgradeMinorVersion) +
      attributeIfContent("protectedSettings", protectedSettings) +
      attributeIfContent("provisionAfterExtensions", provisionAfterExtensions)
  /]

[/#macro]