#!/bin/sh
# HomeRoute VPS desired-state renderer.
# It never calls Docker and never prints secret values.

set -eu

present() {
    name=$1
    eval "value=\${$name:-}"
    if [ -n "$value" ]; then
        printf 'SET'
    else
        printf 'NOT_SET'
    fi
}

blocked=0
require_local() {
    name=$1
    label=$2
    state=$(present "$name")
    printf 'HOMEROUTE_VPS_DESIRED %s=%s\n' "$label" "$state"
    [ "$state" = SET ] || blocked=$((blocked + 1))
}

printf '%s\n' 'HOMEROUTE_VPS_DESIRED schema=1'
printf '%s\n' 'HOMEROUTE_VPS_DESIRED mode=render_only'
printf '%s\n' 'HOMEROUTE_VPS_DESIRED dns_network=amnezia-dns-net'
printf '%s\n' 'HOMEROUTE_VPS_DESIRED awg_container=amnezia-awg2'
printf '%s\n' 'HOMEROUTE_VPS_DESIRED awg_restart_policy=always'
printf '%s\n' 'HOMEROUTE_VPS_DESIRED awg_network_mode=bridge'
printf '%s\n' 'HOMEROUTE_VPS_DESIRED awg_additional_network=amnezia-dns-net'
printf '%s\n' 'HOMEROUTE_VPS_DESIRED awg_privileged=true'
printf '%s\n' 'HOMEROUTE_VPS_DESIRED awg_container_port=35404/udp'
printf '%s\n' 'HOMEROUTE_VPS_DESIRED awg_state_path=/opt/amnezia/awg'
printf '%s\n' 'HOMEROUTE_VPS_DESIRED awg_state_backup_required=true'
printf '%s\n' 'HOMEROUTE_VPS_DESIRED adguard_container=adguard-home'
printf '%s\n' 'HOMEROUTE_VPS_DESIRED adguard_restart_policy=unless-stopped'
printf '%s\n' 'HOMEROUTE_VPS_DESIRED adguard_network_mode=amnezia-dns-net'
printf '%s\n' 'HOMEROUTE_VPS_DESIRED adguard_privileged=false'
printf '%s\n' 'HOMEROUTE_VPS_DESIRED adguard_host_ports=none'

require_local HOMEROUTE_AWG_IMAGE awg_image
require_local HOMEROUTE_AWG_MODULES_SOURCE awg_modules_source
require_local HOMEROUTE_AWG_HOST_UDP_PORT awg_host_udp_port
require_local HOMEROUTE_AWG_STATE_SOURCE awg_state_source
require_local HOMEROUTE_ADGUARD_IMAGE adguard_image
require_local HOMEROUTE_ADGUARD_CONF_SOURCE adguard_conf_source
require_local HOMEROUTE_ADGUARD_WORK_SOURCE adguard_work_source

if [ "$blocked" -gt 0 ]; then
    printf 'HOMEROUTE_VPS_DESIRED result=BLOCKED missing_local_parameters=%s\n' "$blocked"
    exit 2
fi

printf '%s\n' 'HOMEROUTE_VPS_DESIRED result=READY_FOR_SANDBOX_RENDER'
exit 0
