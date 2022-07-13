#!/bin/bash

#####################################################################################################################################
##### FUNCTIONS #####
#####################################################################################################################################

# Config function to parse arguments
config_fetching(){
    # Config file path
    file_config="./config.json"

    argument_line_nr="$(awk "/${1}/"'{ print NR; exit }' ${file_config})" # Stores the Row Nº where the config argument is written
    default_arg="$(head -n ${argument_line_nr} ${file_config} | tail -1 | awk "/${1}/"'{print}')" # Stores the old setting of all config arguments
    trimmed=$(echo ${default_arg} | cut -d ':' -f2 | cut -d ',' -f1 | cut -d '"' -f2 | cut -d '"' -f2)
    echo ${trimmed} | cut -d '"' -f2 | cut -d '"' -f2
}

# GLOBAL VARIABLES
# Defining base PATH
BASE_DIR=$(dirname "${BASH_SOURCE[0]}")
[[ "${BASE_DIR}" != "." ]] || BASE_DIR=$(pwd)

# Arguments fishing from config file:
# Name of the Virtual machine (VM)
ARG1=$(config_fetching "Name")

# QEMU name
VD_NAME="${ARG1}.qcow2"
OS_IMG="${VSD_path}/${VD_NAME}"

# RAM for VM
VD_RAM=$(config_fetching "RAM")

# Defining HugePage default sizes
big_pages="1048576"
small_pages="2048"
# Boot Logs file
BOOT_LOGS_PATH="${BASE_DIR}/boot_logs.txt"

# Grab disk size 
VSD_path="${BASE_DIR}/Tunned_VM/QFT/Virtual_Disks"
cd ${VSD_path}
Disk_Size=$(du -h ${VD_NAME} | awk '{print $1}' | cut -d 'G' -f1)
cd ${BASE_DIR}

set_variables(){
    
	# Process clusters
	process_cluster

    # Cache Clean interval in seconds
	Cache_Clean_Interval=$(config_fetching "Cache Clean")
	# Pinned vCPU
	vCPU_PINNED=$(cat /sys/devices/system/cpu/cpu*/topology/thread_siblings_list | sort | uniq | tail -1)

	# Common Args
	QEMU_ARGS=(
        "-name" "${ARG1}" \
        "-enable-kvm" \
        "-m" "${VD_RAM}G" \
	)

	# Specific Args
	QEMU_ARGS+=(
		"-cpu" "max,pdpe1gb,kvm=off,hv_relaxed,hv_spinlocks=0x1fff,hv_vapic,hv_time" \
		"-mem-path" "/dev/hugepages" \
		"-mem-prealloc" \
		"-machine" "accel=kvm,kernel_irqchip=on" \
		"-rtc" "base=localtime,clock=host" \
		"-drive" "file=${OS_IMG},l2-cache-size=${L2_Cache_Size},cache=writethrough,cache-clean-interval=${Cache_Clean_Interval}" \
	)
}

# Scheduler FIFO processes
sched(){
    while :; do
        if [ -f  ${BOOT_LOGS_PATH} ]; then
            while IFS= read -r line; do
                cur_bytes=$(echo ${line} | awk '{print $5}')
                if [[ ${cur_bytes} != '512' ]]; then
                    # Get parent PID of QEMU VM                                
                    PARENT_PID=$(pstree -pa $(pidof qemu-system-x86_64) | grep ${ARG1} | cut -d','  -f2 | cut -d' ' -f1)
                    # Set all threads of parent PID to SCHED_FIFO 99 priority
                    pstree -pa $PARENT_PID | cut -d','  -f2 | cut -d' ' -f1 | xargs -L1 echo "chrt -f -p 99" | bash
                    exit 0
                fi
            done < ${BOOT_LOGS_PATH}
        fi
    done 
}

# Process Cluster Sizes
process_cluster(){
    arr_cs_valid=("64","128","256","512","1024","2048")
	# Virtual Storage Device (VSD) -- virtual hard drive size in GiB
    # is automatically grabbed from QCOW2 file
    # Cluster Size in KiB
	cluster_size_value=$(config_fetching "VSD Cluster")
	Cluster_Size="${cluster_size_value}K"
	L2_calculated=0
	if [[ "${arr_cs_valid[@]}" =~ "${cluster_size_value}" ]]; then
		auxiliar_calc=$(( ${cluster_size_value}/8 ))
		L2_calculated=$(( ${Disk_Size}/${auxiliar_calc} + 1 ))
	else
		echo "Invalid Cluster Size. Edit value in config.json"
        echo "64, 128, 256, 512, 1024, 2048"
        exit 0
	fi
	L2_Cache_Size="${L2_calculated}M"
}

# LAUNCHER for VM
vm_launcher(){
    ################################ PART I ##############################
	echo "Launching VM..."
	
    # Runnig in parallel process priority scheduler
	sched &

    ################################ PART II ##############################
    # If cset gives you mount error is because newer version of Linux:
    # Just add this to the grub file: GRUB_CMDLINE_LINUX="systemd.unified_cgroup_hierarchy=0"
    # Creating isolated set to launch qemu
    sudo cset shield --cpu=${vCPU_PINNED} --threads --kthread=on >/dev/null 
    # Run VM the -d is to detect when windows boots
    #sudo cset shield -e \
    #qemu-system-x86_64 -- ${QEMU_ARGS[@]} -d trace:qcow2_writev_done_part 2> ${boot_logs_path} >/dev/null

    # check if QEMU_BIN has specific trace event using
    ${QEMU_BIN} -d help
    [ $? = 0 ] && echo "-d trace:qcow2_writev_done_part" || echo "use boot logs (VDT)"

}


unsetup() {
    ################################ PART III ##############################
	# Free resources
	echo "Freeing resources..."
	delete_cset >/dev/null


	# Remove boot file
	sudo rm -f ${BOOT_LOGS_PATH}
}


# Delete cset prevously created
delete_cset(){
    sudo cset set -d system
    while [[ $(sudo cset set -d system) =~ "done" ]]; do 
        sudo cset set -d system
    done
    sudo cset set -d user
}

#####################################################################################################################################
##### MAIN #####
#####################################################################################################################################

set_variables
vm_launcher

echo "Exit success!"