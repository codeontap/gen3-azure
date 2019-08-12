#!/usr/bin/env bash

[[ -n "${GENERATION_DEBUG}" ]] && set ${GENERATION_DEBUG}
trap '. ${GENERATION_DIR}/cleanupContext.sh' EXIT SIGHUP SIGINT SIGTERM
. "${GENERATION_DIR}/common.sh"

# Defaults
DEPLOYMENT_INITIATE_DEFAULT="true"
DEPLOYMENT_MONITOR_DEFAULT="true"
DEPLOYMENT_OPERATION_DEFAULT="update"
DEPLOYMENT_WAIT_DEFAULT=30
DEPLOYMENT_SCOPE_DEFAULT="resourceGroup"

function usage() {
  cat <<EOF

  Manage an Azure Resource Manager (ARM) deployment

  # TODO(rossmurr4y): add usage example on completion
  Usage:

  where

  (o) -d (DEPLOYMENT_OPERATION=delete)  to delete the deployment
      -h                                shows this text
  (o) -i (DEPLOYMENT_MONITOR=false)     initiates but does not monitor the deployment operation.
  (m) -l LEVEL                          is the deployment level - "account", "product", "segment", "solution", "application" or "multiple"
  (o) -m (DEPLOYMENT_INITIATE=false)    monitors but does not initiate the deployment operation.
  (o) -n DEPLOYMENT_NAME                to override the standard deployment naming.
  (o) -r REGION                         is the Azure location/region code for this deployment.
  (o) -s DEPLOYMENT_SCOPE               the deployment scope - "subscription" or "resourceGroup"
  (m) -u DEPLOYMENT_UNIT                is the deployment unit used to determine the deployment template.
  (o) -w DEPLOYMENT_WAIT                the interval between checking the progress of a stack operation.
  (o) -z DEPLOYMENT_UNIT_SUBSET         is the subset of the deployment unit required.

  (m) mandatory, (o) optional, (d) deprecated

  DEFAULTS:

  DEPLOYMENT_INITIATE  = ${DEPLOYMENT_INITIATE_DEFAULT}
  DEPLOYMENT_MONITOR   = ${DEPLOYMENT_MONITOR_DEFAULT}
  DEPLOYMENT_OPERATION = ${DEPLOYMENT_OPERATION_DEFAULT}
  DEPLOYMENT_WAIT      = ${DEPLOYMENT_WAIT_DEFAULT} seconds

EOF
}

function options() {
  # Parse options
  while getopts ":dhil:mn:r:s:u:w:z:" option; do
    case "${option}" in
      d) DEPLOYMENT_OPERATION=delete ;;
      h) usage; return 1 ;;
      i) DEPLOYMENT_MONITOR=false ;;
      l) LEVEL="${OPTARG}" ;;
      m) DEPLOYMENT_INITIATE=false ;;
      n) DEPLOYMENT_NAME="${OPTARG}" ;;
      r) REGION="${OPTARG}" ;;
      s) DEPLOYMENT_SCOPE="${OPTARG}" ;;
      u) DEPLOYMENT_UNIT="${OPTARG}" ;;
      w) DEPLOYMENT_WAIT="${OPTARG}" ;;
      # TODO(rossmurr4y): Impliment az cli dry-run when available - https://github.com/Azure/azure-cli/issues/5549
      z) DEPLOYMENT_UNIT_SUBSET="${OPTARG}" ;;
      \?) fatalOption; return 1 ;;
      :) fatalOptionArgument; return 1;;
    esac
  done

  # Apply defaults if necessary
  DEPLOYMENT_OPERATION=${DEPLOYMENT_OPERATION:-${DEPLOYMENT_OPERATION_DEFAULT}}
  DEPLOYMENT_WAIT=${DEPLOYMENT_WAIT:-${DEPLOYMENT_WAIT_DEFAULT}}
  DEPLOYMENT_INITIATE=${DEPLOYMENT_INITIATE:-${DEPLOYMENT_INITIATE_DEFAULT}}
  DEPLOYMENT_MONITOR=${DEPLOYMENT_MONITOR:-${DEPLOYMENT_MONITOR_DEFAULT}}
  DEPLOYMENT_SCOPE=${DEPLOYMENT_SCOPE:-${DEPLOYMENT_SCOPE_DEFAULT}}

  # Set up the context
  info "Preparing the context..."
  . "${GENERATION_DIR}/setStackContext.sh"

  return 0
}

function construct_parameter_inputs() {

  # if composites haven't run yet, do so
  [[ ! -e ${COMPOSITE_STACK_OUTPUTS} ]] &&
    assemble_composite_stack_outputs

  # temp files
  arm_composite_stack_outputs="${tmp_dir}/arm_composite_stack_outputs"
  #template_parameter_defaults="${tmp_dir}/template_parameter_defaults"
  template_configs="${tmp_dir}/template_configs"
  parameter_library="${tmp_dir}/parameter_library"

  # Merge Composite Outputs + Template Config Files + Parameter Defaults into one lookup library
  # Precedence: Composite Outputs > Template Configs > Default Values
  jq 'to_entries | map({(.key): (.value.value)}) | .[]' < ${COMPOSITE_STACK_OUTPUTS} | jq -s 'add' > ${arm_composite_stack_outputs}
  #jq '.parameters | map_values(select(has("defaultValue"))) | if . == null then {} else . end' < ${TEMPLATE} | jq 'to_entries | map({(.key): (.value.defaultValue)}) | .[]' | jq -s 'add' > ${template_parameter_defaults}
  [[ -f ${CONFIG} ]] &&
    jq '.parameters | to_entries | map({(.key): (.value.value)}) | .[]' < ${CONFIG} | jq -s 'add' > ${template_configs}

  # Construct filter multiplier args
  merge_filter_files=()
  if [[ -f ${arm_composite_stack_outputs} && $(cat "${arm_composite_stack_outputs}") != "null" && $(cat "${arm_composite_stack_outputs}") != "[]" ]]; then
   merge_filter_files+=("${arm_composite_stack_outputs}")
  fi 
  if [[ -f ${template_configs}  && $(cat "${template_configs}") != "null" && $(cat "${template_configs}") != "{}" ]]; then 
    merge_filter_files+=("${template_configs}")
  fi 

  #if [[ -f ${template_parameter_defaults}  && $(cat "${template_parameter_defaults}") != "null" && $(cat "${template_parameter_defaults}") != "{}" ]]; then  
  #  merge_filter_files+=("${template_parameter_defaults}")
  #fi

  jqMerge "${merge_filter_files[@]}" > ${parameter_library}

  # Iterate over template parameters + retreive from assembled outputs/defaults
  arrayFromList template_required_parameters "$(jq '.parameters | keys | .[]' < ${TEMPLATE})"
  output_parameter_json=('{"$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#", "contentVersion": "1.0.0.0", "parameters": {}}')
  for parameter in ${template_required_parameters[@]}; do 
    output_parameter_json+=$(cat "${parameter_library}" | jq --argjson parameter "${parameter}" 'to_entries[] | select( .key == $parameter ) | { (.key) : {"value": (.value)}}' )
  done
  template_inputs=$(echo "${output_parameter_json}" | jq -s 'add')

  # Compare the template_required_parameters length with template_inputs keys, return if same
  #number_of_compiled_inputs=$(echo ${template_inputs} | jq '. | keys | length')
  #number_of_required_inputs=$(echo ${#template_required_parameters[@]})
  #if [[ ${number_of_compiled_inputs} -ne ${number_of_required_inputs} ]]; then

    #debug "Template inputs: ${template_inputs}"
    #debug "Required inputs: ${template_required_parameters[@]}"

    #if [[ -f ${CONFIG} ]]; then
    #  fatal "Incorrect number of compiled inputs. Provide missing parameters in the config file: ${CONFIG}"
    #  break
    #else
    #  fatal "Incorrect number of compiled inputs. Are you missing a config file?"
     # break
    #fi

 # else
    echo "${template_inputs}"
    return 0
  #fi
}

function wait_for_deployment_execution() {

  # Assign the object path to the deployment state.
  status_attribute='.properties.provisioningState'

  info "Watching deployment execution..."

  while true; do

    case ${DEPLOYMENT_OPERATION} in
      update | create)
        if [[ ${DEPLOYMENT_SCOPE} == "resourceGroup" ]]; then
          DEPLOYMENT=$(az group deployment show --resource-group ${DEPLOYMENT_NAME} --name ${DEPLOYMENT_NAME})
        else
          DEPLOYMENT=$(az deployment show --name ${DEPLOYMENT_NAME})
        fi
      ;;
      delete) 
        # Delete the group not the deployment. Deleting a deployment has no impact on deployed resources in Azure.
        DEPLOYMENT=$(az group show --resource-group ${DEPLOYMENT_NAME} 2>/dev/null) 
      ;;
      *)
        fatal "\"${DEPLOYMENT_OPERATION}\" is not one of the known stack operations."; return 1
      ;;
    esac

    if [[ "${DEPLOYMENT_MONITOR}" = "true" ]]; then

      DEPLOYMENT_STATE="$(echo "${DEPLOYMENT}" | jq -r "${status_attribute}")"
      NOW=$( date '+%F_%H:%M:%S' )

      info "[${NOW}] Provisioning State is \"${DEPLOYMENT_STATE}\"."

      case ${DEPLOYMENT_STATE} in
        Failed) 
          exit_status=255
        ;;
        Running | Accepted | Deleting)
          info "    Retry in ${DEPLOYMENT_WAIT} seconds..."
          sleep ${DEPLOYMENT_WAIT} 
        ;;
        Succeeded) 
          # Retreive the deployment
          echo ${DEPLOYMENT} | jq '.' > ${STACK} || return $?
          exit_status=0
          break
        ;;
        *)
          if [[ ${DEPLOYMENT_OPERATION} == "delete" ]]; then
            # deletion successful
            exit_status=0
            break
          else
            fatal "Unexpected deployment state of \"${DEPLOYMENT_STATE}\" "
            exit_status=255
          fi
        ;;
      esac

    fi

    case ${exit_status} in
      0)
      ;;
      255) 
        fatal "Deployment \"${DEPLOYMENT_NAME}\" failed, fix deployment before retrying"
        break
      ;;
      *)
        return ${exit_status} ;;
    esac

  done

}

function process_deployment() {

  stripped_template_file="${tmp_dir}/stripped_template"
  stripped_parameter_file="${tmp_dir}/stripped_parameters"

  # Determine template scope. https://tinyurl.com/y6do25ng
  if [[ -z ${SCOPE} ]]; then
    # set scope to resource group level
    DEPLOYMENT_SCOPE="resourceGroup"
  else
    # set scope to subscription level
    DEPLOYMENT_SCOPE="subscription"
  fi

  # Strip excess from the template + parameters
  jq -c '.' < ${TEMPLATE} > "${stripped_template_file}"
  stripped_parameters="$(construct_parameter_inputs)"
  echo "${stripped_parameters}" | jq -c '.' > "${stripped_parameter_file}"

  exit_status=0
  # Check resource group status
  info "Checking if the ${DEPLOYMENT_NAME} resource group exists..."
  DEPLOYMENT_GROUP_EXISTS=$(az group exists --resource-group "${DEPLOYMENT_NAME}")
  debug "${DEPLOYMENT_NAME} exists: ${DEPLOYMENT_GROUP_EXISTS}"

  if [[ "${DEPLOYMENT_INITIATE}" = "true" ]]; then

    case ${DEPLOYMENT_OPERATION} in
      create | update)

        if [[ "${DEPLOYMENT_SCOPE}" == "resourceGroup" ]]; then

          if [[ ${DEPLOYMENT_GROUP_EXISTS} = "false" ]]; then
            az group create --resource-group "${DEPLOYMENT_NAME}" --location "${REGION}"
          fi

          # validate deployment (resource group must exist for validation though no action taken)
          info "Validating template syntax..."
          az group deployment validate \
            --resource-group "${DEPLOYMENT_NAME}" \
            --template-file "${stripped_template_file}" \
            --parameters @"${stripped_parameter_file}" > /dev/null || return $?
          info "Template is valid."

          # Execute the deployment to the resource group
          info "Starting deployment of ${DEPLOYMENT_NAME} to the resource group."
          az group deployment create \
            --resource-group "${DEPLOYMENT_NAME}" \
            --name "${DEPLOYMENT_NAME}" \
            --template-file "${stripped_template_file}" \
            --parameters @"${stripped_parameter_file}" \
            --no-wait > /dev/null || return $?
        
        elif [[ "${DEPLOYMENT_SCOPE}" == "subscription" ]]; then

          # Execute the deployment to the subscription
          info "Starting deployment of ${DEPLOYMENT_NAME} to the subscription."
          az deployment create --location "${REGION}" \
            --name "${DEPLOYMENT_NAME}" \
            --template-file "${stripped_template_file}" \
            --parameters @"${stripped_parameter_file}" \
            --no-wait > /dev/null || return $?

        fi

        wait_for_deployment_execution
      ;;
      delete)

        if [[ "${DEPLOYMENT_GROUP_EXISTS}" = "true" ]]; then

          # Delete the resource group
          info "Deleting the ${DEPLOYMENT_NAME} resource group"
          az group delete --resource-group "${DEPLOYMENT_NAME}" --no-wait --yes

          wait_for_deployment_execution

          # Clean up the stack if required
          if [[ ("${exit_status}" -eq 0) || !( -s "${STACK}" ) ]]; then
            rm -f "${STACK}"
          fi

        else
          info "No Resource Group found for: ${DEPLOYMENT_NAME}. Nothing to do."
          return 0
        fi


      ;;
      *)
        fatal "\"${DEPLOYMENT_OPERATION}\" is not one of the known stack operations."; return 1
        ;;
    esac
  fi

  return "${exit_status}"
}

function main() {

  options "$@" || return $?

  pushTempDir "manage_deployment_XXXXXX"
  export tmp_dir="$(getTopTempDir)"

  pushd ${CF_DIR} > /dev/null 2>&1

  # TODO(rossmurr4y): impliment prologue script when necessary.

  process_deployment_status=0
  # Process the deployment
  info "processing the deployment"
  process_deployment || process_deployment_status=$?

  # Check for completion
  case ${process_deployment_status} in
    0)
      info "${DEPLOYMENT_OPERATION} completed for ${DEPLOYMENT_NAME}."
    ;;
    *)
      fatal "There was an issue during deployment."
      return ${process_deployment_status}
  esac

  assemble_composite_stack_outputs

  # TODO(rossmurr4y): deleting an identity through resource group deletion does not
  #                   delete the subscription-level role assignments. Microsoft claim
  #                   its safe to leave them, but we should tidy them up.
  #                   https://tinyurl.com/y38rfoyb
  #              
  # Delete any newly vacant role assignments
  #if [[ ${DEPLOYMENT_OPERATION} == "delete" ]]; then
  #  info "Tidying up any unused role assignments..."
  #  empty_servicePrincipalIds=$(az role assignment list --query "[?principalName=='']" -o json | jq -r '.[]["principalId"]')
  #  
  #  if [[ -n ${empty_servicePrincipals} ]]; then 
  #    az role assignment delete --ids ${empty_servicePrincipalIds}
  #  fi
  #fi

  # TODO(rossmurr4y): impliment epilogue script when necessary.

  return 0
}

main "$@" || true