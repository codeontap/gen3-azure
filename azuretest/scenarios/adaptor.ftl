[#ftl]

[#macro azuretest_scenario_adaptor]

    [@addScenario
        settingSets=[]
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
                                "Fragment" : "MockFragment"
                            }
                        }
                    }
                }
            },
            "TestCases" : {
                "baseadaptortemplate" : {
                    "OutputSuffix" : "prologue.sh",
                    "Structural" : {
                        "JSON" : {
                            "Match" : {
                                "LinkedId" : {
                                    "Path" : "",
                                    "Value" : "/subscriptions/12345678-abcd-efgh-ijkl-123456789012/resourceGroups/mockRG/providers/Microsoft.Mock/mockR/mock-resource-name"
                                }
                            }
                        }
                    }
                }
            },
            "TestProfiles" : {
                "Component" : {
                    "adaptor" : {
                        "TestCases" : [ "baseadaptortemplate" ]
                    }
                }
            }
        }
        stackOutputs=[]
        commandLineOption={}
    /]

[/#macro]