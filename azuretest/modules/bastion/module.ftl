[#ftl]

[@addModule
    name="bastion"
    description="Testing module for the azure bastion component"
    provider=AZURETEST_PROVIDER
    properties=[]
/]


[#macro azuretest_module_bastion ]

    [@loadModule
        settingSets=[]
        blueprint={
            "Tiers" : {
                "mgmt" : {
                    "Components" : {
                        "bastion" : {
                            "bastion" : {
                                "Instances" : {
                                    "default" : {
                                        "DeploymentUnits" : [ "segment-az-bastion-base" ]
                                    }
                                },
                                "Enabled" : true,
                                "MultiAZ": false,
                                "Profiles" : {
                                    "Testing" : [ "Component" ]
                                }
                            }
                        }
                    }
                }
            },
            "TestCases" : {
                "basebastiontemplate" : {
                    "OutputSuffix" : "template.json",
                    "Structural" : {
                        "JSON" : {
                            "Match" : {
                                "ScaleSetID" : {
                                    "Path" : "outputs.vmssXmanagementXsshXbastion.value",
                                    "Value" : "/subscriptions/12345678-abcd-efgh-ijkl-123456789012/resourceGroups/mockRG/providers/Microsoft.Mock/mockR/mock-resource-name"
                                }
                            }
                        }
                    }
                }
            },
            "TestProfiles" : {
                "Component" : {
                    "bastion" : {
                        "TestCases" : [ "basebastiontemplate" ]
                    }
                }
            }
        }
        stackOutputs=[]
        commandLineOption={}
    /]

[/#macro]
