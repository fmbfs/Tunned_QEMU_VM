#!/bin/bash

#####################################################################################################################################
##### GLOBAL VARIABLES #####
#####################################################################################################################################

# Defining base PATH
BASE_DIR=$(dirname "${BASH_SOURCE[0]}")
[[ "${BASE_DIR}" != "." ]] || BASE_DIR=$(pwd)

grub_path="/etc/default/grub"
grub_cmdline="#*.json"

#####################################################################################################################################
##### FUNCTIONS #####
#####################################################################################################################################

# Config function to parse arguments
config_fetching(){
    # Config file path
    file_config="${config_file_path}"
    
    argument_line_nr="$(awk "/${1}/"'{ print NR; exit }' ${file_config})" # Stores the Row Nº where the config argument is written
    default_arg="$(head -n ${argument_line_nr} ${file_config} | tail -1 | awk "/${1}/"'{print}')" # Stores the old setting of all config arguments
    trimmed=$(echo ${default_arg} | cut -d ':' -f2 | cut -d ',' -f1)
    echo ${trimmed} | cut -d '"' -f2 | cut -d '"' -f2
}

# Set Variables
set_variables(){
    # Arguments fishing from config file:
    # Name of the Virtual machine (VM)
    VSD_name=$(basename ${VSD_path})

    # RAM for VM
    VD_RAM=$(config_fetching "RAM")

    # Boot Log Flag 
    BOOT_FLAG=$(config_fetching "BOOT FLAG")

    # Cache Clean interval in seconds
	Cache_Clean_Interval=$(config_fetching "CACHE CLEAN")

	# Process clusters
	process_cluster

	# Pinned vCPU
	vCPU_PINNED=$(cat /sys/devices/system/cpu/cpu*/topology/thread_siblings_list | sort | uniq | tail -1)

    # No futuro meter CONFIG_JSON and grab what is infront - TODO
    argument_line_nr="$(awk "/${grub_cmdline}/"'{ print NR; exit }' ${grub_path})"
    config_file_path="$(head -n ${argument_line_nr} ${grub_path} | tail -1 | awk "/#*.json/"'{print}' | cut -d '#' -f2)"
    # grub_tuned_ubuntu22="${grub_cmdline}=\"systemd.unified_cgroup_hierarchy=0\""
    # grub_default="${grub_cmdline}_DEFAULT=\"quiet splash\""
    # argument_line_nr="$(awk "/${grub_cmdline}/"'{ print NR; exit }' ${grub_path})"
    # default_arg="$(head -n ${argument_line_nr} ${grub_path} | tail -1 | awk "/${grub_cmdline}_DEFAULT/"'{print}')"
}

# HELP MENU
show_help(){
	echo ""
    echo "${0} [CONFIG FILE PATH]"
    echo "Options:"
    echo "  -h | --help -> Show this help."
    echo ""
    exit 0
}

# SWITCH ARGUMENTS
process_args(){
    for i in "$@"; do
        case "${i}" in
        "-h" | "--help")
            show_help
            shift
            ;;
        "--disk-path")
            VSD_path="${i#*=}"
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
process_cluster(){
    # Grab VSD size
    Disk_Size=$(du -h ${VSD_name} | awk '{print $1}' | cut -d 'G' -f1)

    L2_calculated=0
	# Virtual Storage Device (VSD) -- virtual hard drive size in GiB
    # is automatically grabbed from QCOW2 file
    # Cluster Size (cs) in KiB
    arr_cs_valid=("64","128","256","512","1024","2048")
    cluster_size_value=$(config_fetching "VSD CLUSTER")

	if [[ "${arr_cs_valid[@]}" =~ "${cluster_size_value}" ]]; then 
        Cluster_Size="${cluster_size_value}K"
		aux_calc=$(( ${cluster_size_value}/8 ))
		L2_calculated="$(( ${Disk_Size}/${aux_calc} + 1 ))M"
        echo ${L2_calculated}
	else
		echo "Invalid Cluster Size. Edit value in the file: ${config_file_path}"
        echo "64, 128, 256, 512, 1024, 2048"
	fi
	L2_Cache_Size="${L2_calculated}M"
}

# Set the qemu process priority to RT on Kernel
set_proc_priority() {
    # Get parent PID of QEMU VM
    PARENT_PID=$(pstree -pa $(pidof qemu-system-x86_64) | grep ${VSD_name} | cut -d','  -f2 | cut -d' ' -f1)
    # Set all threads of parent PID to SCHED_FIFO 99 priority
    pstree -pa $PARENT_PID | cut -d','  -f2 | cut -d' ' -f1 | xargs -L1 echo "chrt -f -p 99" | bash
    exit 0
}

# Schedules the process priority on the kernel via Boot Flag
schedule(){
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

# LAUNCHER for VM
config(){
    schedule &

    # Creating isolated set to launch qemu
    sudo cset shield --cpu=${vCPU_PINNED} --threads --kthread=on >/dev/null 
    # Run VM the -d is to detect when windows boots
    #sudo cset shield -e \
    #qemu-system-x86_64 -- ${QEMU_ARGS[@]} -d trace:qcow2_writev_done_part 2> ${BOOT_LOGS_PATH} >/dev/null
}

#####################################################################################################################################
##### MAIN #####
#####################################################################################################################################

process_args $@

process_post_args

set_variables

config