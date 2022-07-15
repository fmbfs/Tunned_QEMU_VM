#!/bin/bash

#####################################################################################################################################
##### GLOBAL VARIABLES #####
#####################################################################################################################################
# Default error handling
#set -euox pipefail
set -euo pipefail

# Defining base PATH
BASE_DIR=$(dirname "${BASH_SOURCE[0]}")
[[ "${BASE_DIR}" == "." ]] && BASE_DIR=$(pwd)

# Grub path
GRUB_PATH="/etc/default/grub"
GRUB_JSON="#CONFIG_JSON="

# Grab the config file path
ARG_LINE_NR="$(awk "/${GRUB_JSON}/"'{ print NR; exit }' ${GRUB_PATH})"
RAW_CONFIG_FILE_PATH="$(head -n ${ARG_LINE_NR} ${GRUB_PATH} | tail -1 | awk "/${GRUB_JSON}/"'{print}' | cut -d '#' -f2)"
CONFIG_FILE_PATH=$(echo ${RAW_CONFIG_FILE_PATH} | cut -d '=' -f2 )

#####################################################################################################################################
##### FUNCTIONS #####
#####################################################################################################################################

# Config function to parse arguments
config_fetching() {
    ARG_LINE_NR="$(awk "/${1}/"'{ print NR; exit }' ${CONFIG_FILE_PATH})" # Stores the Row Nº where the config argument is written
    OLD_CONFIG="$(head -n ${ARG_LINE_NR} ${CONFIG_FILE_PATH} | tail -1 | awk "/${1}/"'{print}')" # Stores the old setting of all config arguments
    TRIMMED=$(echo ${OLD_CONFIG} | cut -d ':' -f2 | cut -d ',' -f1)
    echo ${TRIMMED} | cut -d '"' -f2 | cut -d '"' -f2
}

# Set Variables
set_variables() {
    # Arguments fishing from config file:
    # Name of the Virtual machine (VM)
    VSD_NAME=$(basename ${VSD_PATH})

    # RAM for VM
    VD_RAM=$(config_fetching "RAM")

    # Boot Log Flag 
    BOOT_FLAG=$(config_fetching "BOOT FLAG")

    # Cache Clean interval in seconds
	CCLEAN_INTERVAL=$(config_fetching "CACHE CLEAN")

	# Process clusters
	process_cluster

	# Pinned vCPU
	VCPU_PINNED=$(cat /sys/devices/system/cpu/cpu*/topology/thread_siblings_list | sort | uniq | tail -1)

}

# HELP MENU
show_help() {
	echo ""
    echo "${0} [CONFIG FILE PATH]"
    echo "Options:"
    echo "--disk-path ---> Demands VSD full path as an argument."
    echo "--boot-logs ---> Demands .txt file full path to store boot logs."
    echo "  -h | --help -> Show this help."
    echo ""
    exit 0
}

# SWITCH ARGUMENTS
process_args() {
    for i in "$@"; do
        case "${i}" in
            "-h" | "--help")
                show_help
                shift
                ;;
            --disk-path=*)
                VSD_PATH="${i#*=}"
                shift
                ;;
            --boot-logs=*)
                BOOT_LOGS_PATH="${i#*=}"
                shift
                ;;
            *)
                echo "Unrecognised option. -h or --help for help."
                shift
                ;;
        esac
    done	
}

# Clean boot logs file
process_post_args() {
    if [ -f ${BOOT_LOGS_PATH} ] ; then
        sudo rm -f ${BOOT_LOGS_PATH}
    fi
    sudo touch ${BOOT_LOGS_PATH}
}

# Process Cluster Sizes
process_cluster() {
    # Grab VSD size
    # TODO -- check qcow2 file if less than 1GiB?
    DISK_SIZE=$(du -b ${VSD_PATH} | awk '{print $1}')

    L2_CALCULATED=0
	# Virtual Storage Device (VSD) -- virtual hard drive size in GiB
    # is automatically grabbed from QCOW2 file
    # Cluster Size (cs) in KiB
    #ARR_CS_VALID=("64","128","256","512","1024","2048")
    ARR_CS_VALID=("65536","131072","262144","524288","1048576","2097152")
    CS_VALUE=$(config_fetching "VSD CLUSTER")

    # minimum value of VSD 8GiB before doing calculation
    CHECK_MIN_VSD="8589934592"

	if [[ "${ARR_CS_VALID[@]}" =~ "${CS_VALUE}" ]]; then 
        if [[ "${DISK_SIZE}" -lt "${CHECK_MIN_VSD}" ]]; then
            L2_CACHE_SIZE="1M"
            echo "aqui"
        else
		aux_calc=$(( ${CS_VALUE}/8 ))
		L2_CACHE_SIZE="$(( ${DISK_SIZE}/${aux_calc} + 1 ))M"
        fi
	else
		echo "Invalid Cluster Size. Edit value in the file: ${CONFIG_FILE_PATH}"
        #echo "64, 128, 256, 512, 1024, 2048"
        echo "65536, 131072, 262144, 524288, 1048576, 202097152"
	fi

}

# Set the qemu process priority to RT on Kernel
set_proc_priority() {
    # Get parent PID of QEMU VM
    PARENT_PID=$(pstree -pa $(pidof qemu-system-x86_64) | grep ${VSD_NAME} | cut -d','  -f2 | cut -d' ' -f1)
    # Set all threads of parent PID to SCHED_FIFO 99 priority
    pstree -pa $PARENT_PID | cut -d','  -f2 | cut -d' ' -f1 | xargs -L1 echo "chrt -f -p 99" | bash
    exit 0
}

# Schedules the process priority on the kernel via Boot Flag
# VLAB flag value is: 512
schedule() {
    REACHED_LOGIN=false
    while :; do
        if [ -f  ${BOOT_LOGS_PATH} ]; then
            while IFS= read -r line; do
                if [[ ! "${BOOT_FLAG}" =~ "login" ]] ; then
                    # VLAB - compare bytes value from logs
                    line=$(echo ${line} | awk '{print $5}')
                    if [[ "${line}" != "${BOOT_FLAG}" ]]; then
                        set_proc_priority
                    fi
                elif [[ "${line}" =~ "${BOOT_FLAG}" ]] || [ "${REACHED_LOGIN}" ]; then
                    # VDT - compare login log
                    REACHED_LOGIN=true
                    set_proc_priority
                fi
            done < ${BOOT_LOGS_PATH}
        fi
    done 
}

#####################################################################################################################################
##### MAIN #####
#####################################################################################################################################

# TODO -- alert when no arguments are passed

process_args $@

process_post_args

set_variables

schedule &

#####################################################################################################################################
##### COMMAND TO RUN. EXAMPLE #####
#####################################################################################################################################
#sudo ./qemu_config.sh --disk-path=/home/franciscosantos/Desktop/git/Tunned_QEMU_VM/Tunned_VM/QFT/Virtual_Disks/disk.qcow2 --boot-logs=/home/franciscosantos/Desktop/git/Tunned_QEMU_VM/boot_logs.txt