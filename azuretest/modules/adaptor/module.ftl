[#ftl]

[@addModule
    name="adaptor"
    description="Testing module for the azure adaptor component"
    provider=AZURETEST_PROVIDER
    properties=[]
/]

[#macro azuretest_module_adaptor ]

    [@loadModule
        settingSets=[
            {
                "Type" : "Builds",
                "Scope" : "Products",
                "Namespace" : "mockedup-integration-azure-adaptor-base",
                "Settings" : {
                    "COMMIT" : AZURE_BUILD_COMMIT_MOCK_VALUE,
                    "FORMATS" : ["lambda"]
                }
            }
        ]
        blueprint={
            "Tiers" : {
                "mgmt" : {
                    "Components" : {
                        "adaptortest" : {
                            "adaptor" : {
                                "Instances" : {
                                    "default" : {
                                        "DeploymentUnits" : [ "azure-adaptor-base" ]
                                    }
                                },
                                "Profiles" : {
                                    "Testing" : [ "Component" ]
                                },
                                "Extensions" : [ "MockFragment" ]
                            }
                        }
                    }
                }
            },
            "TestCases" : {},
            "TestProfiles" : {}
        }
        stackOutputs=[]
        commandLineOption={}
    /]

[/#macro]
