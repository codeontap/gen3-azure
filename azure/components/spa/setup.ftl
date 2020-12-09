[#ftl]

[#macro azure_spa_arm_deployment_generationcontract occurrence]
  [@addDefaultGenerationContract subsets=["prologue", "config", "epilogue"] /]
[/#macro]

[#macro azure_spa_arm_deployment occurrence]

  [@debug message="Entering SPA Setup" context=occurrence enabled=false /]

  [#local core = occurrence.Core ]
  [#local solution = occurrence.Configuration.Solution ]
  [#local settings = occurrence.Configuration.Settings ]
  [#local attributes = occurrence.State.Attributes]
  [#local resources = occurrence.State.Resources]

  [#local forwardingPath = attributes["FORWARDING_PATH"]?remove_beginning("/")]

  [#local fragment = getOccurrenceFragmentBase(occurrence)]
  [#local baselineLinks = getBaselineLinks(occurrence, [ "OpsData"], false, false)]
  [#local storageAccount = baselineLinks["OpsData"].State.Attributes["ACCOUNT_NAME"]]
  [#local baselineComponentIds = getBaselineComponentIds(baselineLinks, "", "", "", "container")]
  [#local operationsBlobContainer = baselineLinks["OpsData"].State.Resources["container"].Name]
  [#--[#local operationsBlobContainer = getReference(AZURE_PROVIDER, baselineComponentIds["OpsData"])] --]
  [#local contextLinks = getLinkTargets(occurrence)]

  [#local distributions = []]

  [#-- SPA Context --]
  [#assign _context =
    {
      "Id" : fragment,
      "Name" : fragment,
      "Instance" : core.Instance.Id,
      "Version" : core.Version.Id,
      "DefaultEnvironment" : defaultEnvironment(occurrence, contextLinks, baselineLinks),
      "Environment" : {},
      "Links" : contextLinks,
      "BaselineLinks" : baselineLinks,
      "DefaultCoreVariables" : false,
      "DefaultEnvironmentVariables" : false,
      "DefaultLinkVariables" : false,
      "DefaultBaselineVariables" : false
    }
  ]

  [#-- Add in container specifics including override of defaults --]
  [#local fragmentId = formatFragmentId(_context)]
  [#include fragmentList?ensure_starts_with("/")]

  [#assign _context += getFinalEnvironment(occurrence, _context)]

  [#list _context.Links as id,linkTarget]

    [#local linkTargetCore = linkTarget.Core]
    [#local linkTargetConfiguration = linkTarget.Configuration]
    [#local linkTargetResources = linkTarget.State.Resources]
    [#local linkTargetAttributes = linkTarget.State.Attributes]
    [#local linkDirection = linkTarget.Direction]

    [#switch linkTargetCore.Type]
      [#case CDN_ROUTE_COMPONENT_TYPE]
        [#if linkDirection == "inbound"]
          [#local distributions += [ {
            "DistributionId" : linkTargetAttributes["DISTRIBUTION_ID"],
            "PathPattern" : linkTargetResources["origin"].PathPattern
          }]]
        [/#if]
        [#break]
    [/#switch]

  [/#list]

  [#if ! distributions?has_content]

    [#-- TODO(rossmurr4y): add after CDN component is done.
    [@fatal
      message="An SPA must have at least 1 CDN Route component link - Add an inbound CDN Route link to the SPA"
      context=solution
      enabled=true
    /]--]
  [/#if]

  [#if deploymentSubsetRequired("prologue", false)]
    [#--
      Prologue Script Order of Operations:
      1 - Stage the latest build files
      2 - Unzip/Sync build files with the container
      3 - Stage the latest config
      4 - Sync config with the container
    --]
    [@addToDefaultBashScriptOutput
      content=
        getBuildScript(
          "spaFiles",
          "spa",
          productName,
          occurrence,
          "spa.zip"
        ) +
        syncFilesToBlobContainerScript(
          "spaFiles",
          storageAccount,
          r'\$web',
          forwardingPath
        ) +
        getLocalFileScript(
          "configFiles",
          "$\{CONFIG}",
          "config.json"
        ) +
        syncFilesToBlobContainerScript(
          "configFiles",
          storageAccount,
          r'\$web',
          formatRelativePath(
            getOccurrenceSettingValue(occurrence, "SETTINGS_PREFIX"),
            solution.ConfigPath
          )
        )
    /]
  [/#if]

  [#if deploymentSubsetRequired("config", false)]
    [@addToDefaultJsonOutput
      content={ "RUN_ID" : commandLineOptions.Run.Id } + _context.Environment
    /]
  [/#if]

  [#-- invalidate the old cached content on the CDN with an epilogue script --]
  [#--
  [#if solution.InvalidateOnUpdate && distributions?has_content]
    [#local invalidationScript = []]
    [#list distributions as distribution]

      TODO(rossmurr4y):
      once the CDN component exists, revisit this and ensure the cached data is invalidated.

    [/#list]

    [#if deploymentSubsetRequired("epilogue", false)]
      [@addToDefaultBashScriptOutput
        [
          "case $\{DEPLOYMENT_OPERATION} in",
          "  create|update)"
        ] +
        invalidationScript +
        [
          " ;;",
          " esac"
        ]
      /]
    [/#if]
  [/#if]
  --]
[/#macro]
