[#ftl]

[#macro azuretest_scenario_lb]

    [@addScenario
        settingSets=[]
        blueprint={
            "Tiers" : {
                "elb" : {
                    "Components" : {
                        "lb" : {
                            "lb" : {
                                "Instances" : {
                                    "default" : {
                                        "DeploymentUnits" : [ "solution-az-lb-base" ]
                                    }
                                },
                                "Profiles" : {
                                    "Testing" : [ "Component" ]
                                },
                                "Engine" : "application",
                                "Ports" : {
                                    "testport" : {
                                        "Enabled" : true
                                    }
                                }
                            }
                        }
                    }
                }
            },
            "TestCases" : {
                "baselbtemplate" : {
                    "OutputSuffix" : "template.json",
                    "Structural" : {
                        "JSON" : {
                            "Match" : {
                                "AppGatewayID" : {
                                    "Path" : "outputs.appGatewayXmockedupXintegrationXelbXlb.value",
                                    "Value" : "/subscriptions/12345678-abcd-efgh-ijkl-123456789012/resourceGroups/mockRG/providers/Microsoft.Mock/mockR/mock-resource-name"
                                }
                            }
                        }
                    }
                }
            },
            "TestProfiles" : {
                "Component" : {
                    "lb" : {
                        "TestCases" : [ "baselbtemplate" ]
                    }
                }
            }
        }
        stackOutputs=[]
        commandLineOption={}
    /]

[/#macro]