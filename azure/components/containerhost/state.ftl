[#ftl]

[#macro azure_containerhost_arm_state occurrence parent={}]

    [#local core = occurrence.Core]
    [#local solution = occurrence.Configuration.Solution]
    [#local isAutoScaling = solution.AutoScaling.Enabled]
    [#local resources = {}]

    [#switch solution.Engine]

        [#default]

            [#local planId = formatResourceId(
                AZURE_APP_SERVICE_PLAN_RESOURCE_TYPE,
                core.FullName)]
            [#local planName = formatAzureResourceName(
                core.FullName,
                AZURE_APP_SERVICE_PLAN_RESOURCE_TYPE)]

            [#local resources += {
                    "plan" : {
                        "Id" : planId,
                        "Name" : planName,
                        "Type" : AZURE_APP_SERVICE_PLAN_RESOURCE_TYPE,
                        "Reference" : getReference(AZURE_PROVIDER, {"Id": planId, "Name": planName})
                    }
                }]

            [#break]

    [/#switch]

    [#if isAutoScaling]
        [#local autoscaleId = formatResourceId(AZURE_AUTOSCALE_SETTINGS_RESOURCE_TYPE, core.ShortName)]
        [#local autoscaleName = formatAzureResourceName(core.ShortName, AZURE_AUTOSCALE_SETTINGS_RESOURCE_TYPE)]
        [#local resources += {
            "autoscale" : {
                "Id" : autoscaleId,
                "Name" : autoscaleName,
                "Type" : AZURE_AUTOSCALE_SETTINGS_RESOURCE_TYPE,
                "Reference" : getReference(AZURE_PROVIDER,{"Id": autoscaleId, "Name": autoscaleName})
            }
        }]
    [/#if]

    [#assign componentState =
        {
            "Resources" : resources,
            "Attributes" : {},
            "Roles" : {}
        }
    ]
[/#macro]