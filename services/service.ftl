[#ftl]

[#-- 
    Services are structured within the plugin by their top-level Azure Service Type.
    Where a large resource definition within a given Service warrants being split into
    several files for maintainability, dot-notation will be used.

    Format: service.resource.subresource

    ie. "microsoft.network.applicationgateways"
--]

[#-- Microsoft.Authorization --]
[#assign AZURE_RBAC_SERVICE = "microsoft.authorization"]

[#-- Microsoft.Compute --]
[#assign AZURE_VIRTUALMACHINE_SERVICE = "microsoft.compute"]

[#-- Microsoft.Insights --]
[#assign AZURE_INSIGHTS_SERVICE = "microsoft.insights"]

[#-- Microsoft.KeyVault --]
[#assign AZURE_KEYVAULT_SERVICE = "microsoft.keyvault"]

[#-- Microsoft.ManagedIdentity --]
[#assign AZURE_IAM_SERVICE = "microsoft.managedidentity"]

[#-- Microsoft.Network --]
[#assign AZURE_NETWORK_SERVICE = "microsoft.network"]
[#assign AZURE_NETWORK_APPLICATION_GATEWAY_SERVICE = "microsoft.network.applicationgateways"]
[#assign AZURE_NETWORK_FRONTDOOR_SERVICE = "microsoft.network.frontdoor"]

[#-- Microsoft.Storage --]
[#assign AZURE_STORAGE_SERVICE = "microsoft.storage"]

[#-- Pseudo services --]
[#assign AZURE_BASELINE_PSEUDO_SERVICE = "baseline"]
