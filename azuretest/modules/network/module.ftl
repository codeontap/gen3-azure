[#ftl]

[@addModule
    name="network"
    description="Testing module for the azure network component"
    provider=AZURETEST_PROVIDER
    properties=[]
/]

[#macro azuretest_module_network ]

    [@loadModule
        settingSets=[]
        blueprint={
            "Tiers" : {
                "mgmt" : {
                    "Components" : {
                        "vnet" : {
                            "network" : {
                                "Instances" : {
                                    "default" : {
                                        "DeploymentUnits" : [ "segment-az-network-base" ]
                                    }
                                },
                                "Profiles" : {
                                    "Testing" : [ "Component" ]
                                },
                                "RouteTables": {
                                    "internal": {},
                                    "external": {
                                        "Public": true
                                    }
                                },
                                "NetworkACLs": {
                                    "open": {
                                        "Rules": {
                                            "in": {
                                                "Priority": 200,
                                                "Action": "allow",
                                                "Source": {
                                                    "IPAddressGroups": [
                                                        "_global"
                                                    ]
                                                },
                                                "Destination": {
                                                    "IPAddressGroups": [
                                                        "_localnet"
                                                    ],
                                                    "Port": "any"
                                                },
                                                "ReturnTraffic": false
                                            },
                                            "out": {
                                                "Priority": 200,
                                                "Action": "allow",
                                                "Source": {
                                                    "IPAddressGroups": [
                                                        "_localnet"
                                                    ]
                                                },
                                                "Destination": {
                                                    "IPAddressGroups": [
                                                        "_global"
                                                    ],
                                                    "Port": "any"
                                                },
                                                "ReturnTraffic": false
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            },
            "TestCases" : {
                "basenetworktemplate" : {
                    "OutputSuffix" : "template.json",
                    "Structural" : {
                        "JSON" : {
                            "Match" : {
                                "VNetID" : {
                                    "Path" : "outputs.vnetXmgmtXvnet.value",
                                    "Value" : AZURE_RESOURCE_ID_MOCK_VALUE
                                }
                            }
                        }
                    }
                }
            },
            "TestProfiles" : {
                "Component" : {
                    "network" : {
                        "TestCases" : [ "basenetworktemplate" ]
                    }
                }
            }
        }
        stackOutputs=[]
        commandLineOption={}
    /]

[/#macro]
