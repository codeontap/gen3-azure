[#ftl]

[@addResourceProfile
  service=AZURE_CONTAINER_SERVICE
  resource=AZURE_CONTAINERS_CLUSTER_RESOURCE_TYPE
  profile=
    {
        "apiVersion" : "2020-06-01",
        "conditions" : [],
        "type" : "Microsoft.ContainerService/managedClusters",
        "outputMappings" : {
            REFERENCE_ATTRIBUTE_TYPE : {
                "Property" : "id"
            },
            URL_ATTRIBUTE_TYPE : {
                "Property" : "properties.fullyQualifiedDomainName"
            }
        }
    }
/]

[#function getContainerAgentPoolProfile name occurrence scaleRules=[]]

    [#local solution = occurrence.Configuration.Solution]

    [#-- Network Resources --]
    [#local subnetId = ""]
    [#local occurrenceNetwork = getOccurrenceNetwork(occurrence)]
    [#local networkLink       = occurrenceNetwork.Link!{}]
    [#local networkLinkTarget = getLinkTarget(occurrence, networkLink)]
    [#if networkLinkTarget?has_content]
        [#local networkResources = networkLinkTarget.State.Resources]
        [#local subnetId = getSubnet(occurrence.Core.Tier, networkResources).Reference]
    [/#if]

    [#-- Profiles --]
    [#local processorProfile = getProcessor(occurrence, ECS_COMPONENT_TYPE)]

    [#local storageProfile = getStorage(occurrence, "ecs")]
    [#local imageProfile = getVMImageProfile(occurrence, "ecs")]
    [#local autoScaleProfile = {}]
    [#if scaleRules?has_content]
        [#local autoScaleProfile =
            getAutoScaleProfile(
                name,
                processorProfile.MinCount,
                processorProfile.MaxCount,
                processorProfile.DesiredCount,
                scaleRules)]
    [/#if]

    [#local orchestratorVersion = solution["azure:OrchestratorVersion"]!""]

    [#return {
        "name" : name,
        "type" : "VirtualMachineScaleSets"
    } +
        attributeIfContent("count", processorProfile.DesiredCount!"") +
        attributeIfContent("vmSize", processorProfile.Processor!"") +
        attributeIfContent("osDiskSizeGB", storageProfile.Volumes.Size!"") +
        attributeIfContent("vnetSubnetID", subnetId!"") +
        attributeIfContent(
            "osType",
            imageProfile.Image,
            imageProfile.Image
                ?contains("Windows")
                    ?then("Windows", "Linux")) +
        attributeIfContent("maxCount", processorProfile.MaxCount!"") +
        attributeIfContent("minCount", processorProfile.MinCount!"") +
        attributeIfTrue("enableAutoScaling", scaleRules?has_content, true) +
        attributeIfContent("orchestratorVersion", orchestratorVersion!"") +
        attributeIfContent("nodeImageVersion", imageProfile.Image!"")]
[/#function]

[#function getContainerClusterNetworkProfile occurrence]
    [#local result = {}]
    [#local networkProfile = getOccurrenceNetwork(occurrence)]

    [#return result]
[/#function]

[#function getContainerClusterOSProfile adminName="azureuser" os="" publicKeyData=""]
    [#if os?has_content]
        [#if os?contains("Windows")]
            [#return
                {
                    "windowsProfile" : {
                        "adminUsername" : adminName
                    }
                }]
        [#else]
            [#return
                {
                    "linuxProfile" : {
                        "adminUsername" : adminName,
                        "ssh" : {
                            "publicKeys" : [ { "keyData" : publicKeyData }]
                        }
                    }
                }]
        [/#if]
    [/#if]
    [#return {}]
[/#function]

[#macro createContainerCluster
    id
    name
    sku
    location
    poolProfiles=[]
    identity={}
    scaleRules=[]
    osProfile={}
    networkProfile={}
    dependsOn=[]]

    [#local properties = {} +
        osProfile +
        attributeIfContent("agentPoolProfiles", poolProfiles) +
        attributeIfContent("networkProfile", networkProfile)]

    [@armResource
        id=id
        name=name
        location=location
        sku=sku
        profile=AZURE_CONTAINERS_CLUSTER_RESOURCE_TYPE
        dependsOn=dependsOn
        properties=properties
    /]
[/#macro]

[#macro createContainerClusterAgentPool]

[/#macro]
