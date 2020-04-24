[#ftl]

[#-- global lookup for user Role names and ids.             --]
[#-- Custom Roles append to this on creation.               --]
[#-- BuiltInRoles to be added as they are utilised in cot.  --]
[#-- https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles --]
[#assign userRoles = {
    "Reader" : {
        "Description" : "Lets you view everything, but not make any changes.",
        "RoleType" : "BuiltInRole",
        "Id" : "acdd72a7-3385-48ef-bd42-f606fba81ae7"
    }
}]

[#-- For retrieving BuiltInRole definitions only.             --]
[#-- CustomRole definition references should be obtained      --]
[#-- through occurrence.State.Resources[<resource>].Reference --]
[#function getRoleReference role subscription=""]
    [#local userRole = userRoles[role]]
    [#return
        getReference(
            AZURE_ROLE_ASSIGNMENT_RESOURCE_TYPE,
            userRole.Id,
            "",
            REFERENCE_ATTRIBUTE_TYPE,
            subscription
        )
    ]
[/#function]

[#-- App Registration Endpoints --]
[#function formatAzureAppRegistrationEndpoint authenticationType subscriptionId endpointType="" ]
    [#local prefix = "https://login.microsoftonline.com/"]
    [#switch authenticationType?lower_case]
        [#case "oauth2"]
        [#case "oauth"]
        [#default]
            [#switch endpointType?lower_case]
                [#case "authorization"]
                    [#local suffix = "/oauth2/v2.0/authorize"]
                    [#break]
                [#case "token1"]
                [#case "tokenv1"]
                    [#local suffix = "/oauth2/token"]
                    [#break]
                [#case "token"]
                [#case "token2"]
                [#case "tokenv2"]
                [#default]
                    [#local suffix = "/oauth2/v2.0/token"]
                    [#break]
            [/#switch]
            [#break]
        [#case "openid"]
            [#local suffix = "/v2.0/.well-known/openid-configuration"]
            [#break]
        [#case "wsfederation"]
            [#local suffix = "/wsfed"]
            [#break]
        [#case "samlp"]
            [#switch endpointType?lower_case]
                [#case "signon"]
                [#case "signout"]
                [#default]
                    [#local suffix = "/saml2"]
                    [#break]
            [/#switch]
            [#break]
    [/#switch]
    [#return prefix + subscriptionId + suffix]
[/#function]