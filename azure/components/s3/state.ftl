[#ftl]

[#macro azure_s3_arm_state occurrence parent={}]
    [#local core = occurrence.Core]
    [#local solution = occurrence.Configuration.Solution]

    [#local storageAccountId = formatResourceId(AZURE_STORAGEACCOUNT_RESOURCE_TYPE, core.Id)]
    [#local containerId = formatResourceId( AZURE_BLOBSERVICE_CONTAINER_RESOURCE_TYPE, core.Id )]
    [#local blobId = formatResourceId( AZURE_BLOBSERVICE_RESOURCE_TYPE, core.Id )]
    [#local secretId = formatResourceId(AZURE_KEYVAULT_SECRET_RESOURCE_TYPE, core.Id )]

    [#local publicAccessEnabled = false]
    [#list solution.PublicAccess?values as publicPrefixConfiguration]
        [#if publicPrefixConfiguration.Enabled]
            [#local publicAccessEnabled = true]
            [#break]
        [/#if]
    [/#list]

    [#local blobName = "default"]
    [#local container = formatName(AZURE_BLOBSERVICE_CONTAINER_RESOURCE_TYPE, core.ShortName)]
    [#local accountName = formatAzureResourceName(core.ShortName, AZURE_STORAGEACCOUNT_RESOURCE_TYPE)]
    [#local blobName = formatAzureResourceName(blobName, AZURE_BLOBSERVICE_RESOURCE_TYPE, accountName)]
    [#local containerName = formatAzureResourceName(container, AZURE_BLOBSERVICE_CONTAINER_RESOURCE_TYPE, blobName)]
    [#local secretName = formatSecretName(core.ShortName, "ConnectionKey")]

    [#local storageEndpoints =
        getReference(
            formatId(
                storageAccountId
                "properties",
                "primaryEndpoints"
            )
        )
    ]

    [#if storageEndpoints?is_string]
        [#local storageEndpoints = {
            "blob" : "",
            "queue" : "",
            "web" : ""
        }]
    [/#if]

    [#assign componentState=
        {
            "Resources" : {
                "storageAccount" : {
                    "Id" : storageAccountId,
                    "Name" : accountName,
                    "Type" : AZURE_STORAGEACCOUNT_RESOURCE_TYPE,
                    "Reference" : getReference(AZURE_PROVIDER, {"Id": storageAccountId, "Name": accountName})
                },
                "blobService" : {
                    "Id" : blobId,
                    "Name" : blobName,
                    "Type" : AZURE_BLOBSERVICE_RESOURCE_TYPE,
                    "Reference" : getReference(AZURE_PROVIDER, {"Id": blobId, "Name": blobName})
                },
                "container" : {
                    "Id" : containerId,
                    "Name" : containerName,
                    "Type" : AZURE_BLOBSERVICE_CONTAINER_RESOURCE_TYPE,
                    "Reference" : getReference(AZURE_PROVIDER, {"Id": containerId, "Name": containerName})
                },
                "secret" : {
                    "Id" : secretId,
                    "Name" : secretName,
                    "Type" : AZURE_KEYVAULT_SECRET_RESOURCE_TYPE,
                    "Reference" : getReference(AZURE_PROVIDER, {"Id": secretId, "Name": secretName})
                }
            },
            "Attributes" : {
                "ACCOUNT_ID" : storageAccountId,
                "ACCOUNT_NAME" : accountName,
                "CONTAINER_NAME" : container,
                "KEY_SECRET" : secretName,
                "PRIMARY_ENDPOINT" : contentIfContent(storageEndpoints.blob, ""),
                "QUEUE_ENDPOINT": contentIfContent(storageEndpoints.queue, ""),
                "WEB_ENDPOINT": contentIfContent(storageEndpoints.web, "")
            },
            "Roles" : {
                "Inbound" : {},
                "Outbound" : {}
            }
        }
    ]
[/#macro]
