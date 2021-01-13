[#ftl]

[#-- 
    Services are structured within the plugin by their top-level Azure Service Type.
    Where a large resource definition within a given Service warrants being split into
    several files for maintainability, dot-notation will be used.

    Format: service.resource.subresource

    ie. "microsoft.network.applicationgateways"
--]

[#-- Microsoft.ApiManagement --]
[#assign AZURE_API_MANAGEMENT_SERVICE = "microsoft.apimanagement"]

[#-- Microsoft.Authorization --]
[#assign AZURE_AUTHORIZATION_SERVICE = "microsoft.authorization"]

[#-- Microsoft.Compute --]
[#assign AZURE_VIRTUALMACHINE_SERVICE = "microsoft.compute"]

[#-- Microsoft.ContainerService --]
[#assign AZURE_CONTAINER_SERVICE = "microsoft.containerservice"]

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

[#-- Microsoft.DBforPostgreSQL --]
[#assign AZURE_DB_POSTGRES_SERVICE = "microsoft.dbforpostgresql"]

[#-- Microsoft.DBforMySQL --]
[#assign AZURE_DB_MYSQL_SERVICE = "microsoft.dbformysql"]

[#-- Microsoft.Resources--]
[#assign AZURE_RESOURCES_SERVICE = "microsoft.resources"]

[#-- Microsoft.Storage --]
[#assign AZURE_STORAGE_SERVICE = "microsoft.storage"]

[#-- Microsoft.Web --]
[#assign AZURE_WEB_SERVICE = "microsoft.web"]

[#-- Pseudo services --]
[#assign AZURE_BASELINE_PSEUDO_SERVICE = "baseline"]
[#assign AZURE_AAD_APP_REGISTRATION_PSEUDO_SERVICE = "microsoft.aad.appregistration"]