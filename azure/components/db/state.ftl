[#ftl]

[#macro azure_db_arm_state occurrence parent={}]

    [#local core = occurrence.Core]
    [#local solution = occurrence.Configuration.Solution]

    [#local dbServerId = formatResourceId(AZURE_DB_POSTGRES_SERVER_RESOURCE_TYPE, core.ShortName)]
    [#local dbServerName = formatAzureResourceName(
        formatName(AZURE_DB_POSTGRES_SERVER_RESOURCE_TYPE, core.ShortName)
        AZURE_DB_POSTGRES_SERVER_RESOURCE_TYPE
    )]
    [#local databaseId = formatResourceId(AZURE_DB_POSTGRES_SERVER_DATABASE_RESOURCE_TYPE, core.ShortName)]
    [#local databaseRawName = solution.DatabaseName!productName]
    [#local databaseName = formatAzureResourceName(
        databaseRawName,
        AZURE_DB_POSTGRES_SERVER_DATABASE_RESOURCE_TYPE,
        dbServerName
    )]

    [#-- One Resource Per Key:Value pair in the DBParameters attribute. --]
    [#local configs = {}]
    [#list solution.DBParameters?keys as key]
        [#local configId = formatResourceId(AZURE_DB_POSTGRES_SERVER_CONFIGURATION_RESOURCE_TYPE, key)]
        [#local configName = formatAzureResourceName(
            key,
            AZURE_DB_POSTGRES_SERVER_CONFIGURATION_RESOURCE_TYPE,
            dbServerName
        )]
        [#local configs += { 
            key : {
                "Id" : configId,
                "Name" : configName,
                "Type" : AZURE_DB_POSTGRES_SERVER_CONFIGURATION_RESOURCE_TYPE,
                "Reference": getReference(AZURE_PROVIDER, {"Id": configId, "Name": configName})
            }}]
    [/#list]

    [#local vnetRuleId = formatResourceId(AZURE_DB_POSTGRES_SERVER_VNET_RULE_RESOURCE_TYPE, core.ShortName)]
    [#local vnetRuleName = formatAzureResourceName(
        formatName(AZURE_DB_POSTGRES_SERVER_VNET_RULE_RESOURCE_TYPE, core.ShortName),
        AZURE_DB_POSTGRES_SERVER_VNET_RULE_RESOURCE_TYPE,
        dbServerName
    )]

    [#-- Credential Management --]
    [#if solution.GenerateCredentials.Enabled]
        [#local masterUsername = solution.GenerateCredentials.MasterUserName]
        [#local masterSecret = formatSecretName(core.ShortFullName)]
    [#else]
        [#-- don't flag an error if credentials missing but component is not enabled --]
        [#local masterUsername = getOccurrenceSettingValue(occurrence, "MASTER_USERNAME", !solution.Enabled) ]
        [#local masterSecret = getOccurrenceSettingValue(occurrence, "MASTER_SECRET", !solution.Enabled) ]
    [/#if]

    [#local fqdn = getReference(AZURE_PROVIDER, {"Id": dbServerId, "Name": dbServerName}, URL_ATTRIBUTE_TYPE)]

    [#assign componentState =
        {
            "Resources" : {
                "dbserver" : {
                    "Id" : dbServerId,
                    "Name" : dbServerName,
                    "Type" : AZURE_DB_POSTGRES_SERVER_RESOURCE_TYPE,
                    "Reference": getReference(AZURE_PROVIDER, {"Id": dbServerId, "Name": dbServerName})
                },
                "database" : {
                    "Id" : databaseId,
                    "Name" : databaseName,
                    "Type" : AZURE_DB_POSTGRES_SERVER_DATABASE_RESOURCE_TYPE,
                    "Reference": getReference(AZURE_PROVIDER, {"Id": databaseId, "Name": databaseName})
                },
                "dbconfigs" : configs,
                "dbvnetrule" : {
                    "Id" : vnetRuleId,
                    "Name" : vnetRuleName,
                    "Type" : AZURE_DB_POSTGRES_SERVER_VNET_RULE_RESOURCE_TYPE,
                    "Reference": getReference(AZURE_PROVIDER, {"Id": vnetRuleId, "Name": vnetRuleName})
                }
            },
            "Attributes" : {
                "DB_NAME" : databaseName?keep_after_last("/"),
                "USERNAME" : masterUsername + '@' + fqdn,
                "FQDN" : fqdn,
                "SECRET" : masterSecret
            },
            "Roles" : {
                "Inbound" : {},
                "Outbound" : {}
            }
        }
    ]
[/#macro]
