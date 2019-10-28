[#ftl
]
[#-- Structure --]

[#function getNetworkAcls 
    defaultAction 
    ipRules=[]
    virtualNetworkRules=[]
    bypass=""]

    [#return
        {
            "defaultAction": defaultAction
        } +
        attributeIfContent("ipRules", asArray(ipRules)) +
        attributeIfContent("virtualNetworkRules", asArray(virtualNetworkRules)) +
        attributeIfContent("bypass", bypass)
    ]
[/#function]

[#function getNetworkAclsVirtualNetworkRules id action="" state=""]
   [#return
        {
            "id" : id
        } +
        attributeIfContent("action", action) +
        attributeIfContent("state", state)
    ]
[/#function]

[#function getNetworkAclsIpRules value action=""]
    [#return
        {
            "value" : value
        } + 
        attributeIfContent("action", action)
    ]
[/#function]