#!/bin/bash

#####################################################################################################################################
##### FUNCTIONS #####
#####################################################################################################################################

# Check for sudo su
check_su(){
	if [[ ${UID} != 0 ]]; then
		echo "
		This script must be run as sudo permissions.
			Please run it as: 
				sudo su ${0}
		"
		exit 1
	fi
}

# Config function to parse arguments
config_fetching(){
    # Config file path
    file_config="./config.json"

    argument_line_nr="$(awk "/${1}/"'{ print NR; exit }' ${file_config})" # Stores the Row Nº where the config argument is written
    default_arg="$(head -n ${argument_line_nr} ${file_config} | tail -1 | awk "/${1}/"'{print}')" # Stores the old setting of all config arguments
    trimmed=$(echo ${default_arg} | cut -d ':' -f2 | cut -d ',' -f1)
    echo ${trimmed} | cut -d '"' -f2 | cut -d '"' -f2
}

# GLOBAL VARIABLES
# Defining base PATH
BASE_DIR=$(dirname "${BASH_SOURCE[0]}")
[[ "${BASE_DIR}" == "." ]] && BASE_DIR=$(pwd)

# Arguments fishing from config file:
# Name of the Virtual machine (VM)
ARG1=$(config_fetching "Name")

# RAM for VM
VD_RAM=$(config_fetching "RAM")

# Defining HugePage default sizes
big_pages="1048576"
small_pages="2048"
# Boot Logs file
boot_logs_path="${BASE_DIR}/boot_logs.txt"

# Grab disk size 
VSD_path="${BASE_DIR}/Tunned_VM/QFT/Virtual_Disks"
cd ${VSD_path}
Disk_Size=$(du -h ${VD_NAME} | awk '{print $1}' | cut -d 'G' -f1)
cd ${BASE_DIR}

set_variables(){
	# QEMU name
	VD_NAME="${ARG1}.qcow2"
	OS_IMG="${VSD_path}/${VD_NAME}"
    
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

# Delete cset prevously created
delete_cset(){
    sudo cset set -d system
    while [[ $(sudo cset set -d system) =~ "done" ]]; do 
        sudo cset set -d system
    done
    sudo cset set -d user
}

# Scheduler FIFO processes
sched(){
    while :; do
        if [ -f  ${boot_logs_path} ]; then
            while IFS= read -r line; do
                cur_bytes=$(echo ${line} | awk '{print $5}')
                if [[ ${cur_bytes} != '512' ]]; then
                    # Get parent PID of QEMU VM                                
                    PARENT_PID=$(pstree -pa $(pidof qemu-system-x86_64) | grep ${ARG1} | cut -d','  -f2 | cut -d' ' -f1)
                    # Set all threads of parent PID to SCHED_FIFO 99 priority
                    pstree -pa $PARENT_PID | cut -d','  -f2 | cut -d' ' -f1 | xargs -L1 echo "chrt -f -p 99" | bash
                    exit 0
                fi
            done < ${boot_logs_path}
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

# Huge Pages set-up.
page_size(){
    # Total page calculation
    total_pages=$(( ${VD_RAM} * ${big_pages} / ${small_pages} ))
    # Big pages
    if [ "$(grep Hugepagesize /proc/meminfo | awk '{print $2}')" == "${big_pages}" ]; then
        hugepages "${big_pages}" "${VD_RAM}"
        grubsm
    # Small pages
    elif [ "$(grep Hugepagesize /proc/meminfo | awk '{print $2}')" == "${small_pages}" ]; then 
        hugepages "${small_pages}" "${total_pages}"
        grubsm
    else
        print_error "HP_2 - ${small_pages} Not avalilable"
    fi
}

# Allocate huge pages size
hugepages(){
    sysctl -w vm.nr_hugepages="${2}"
    # Disable THP 
    echo "never" > "/sys/kernel/mm/transparent_hugepage/enabled"
    echo "never" > "/sys/kernel/mm/transparent_hugepage/defrag"
    
    for i in $(find /sys/devices/system/node/node* -maxdepth 0 -type d); do
        echo "${2}" > "$i/hugepages/hugepages-${1}kB/nr_hugepages"    
    done
}

# Free allocated huge pages size
free_hugepages(){
    sysctl -w vm.nr_hugepages="0"
    # Enable THP
    echo "always" > "/sys/kernel/mm/transparent_hugepage/enabled"
    echo "always" > "/sys/kernel/mm/transparent_hugepage/defrag"

    for i in $(find /sys/devices/system/node/node* -maxdepth 0 -type d); do
        echo 0 > "$i/hugepages/hugepages-${1}kB/nr_hugepages"
        echo 0 > "$i/hugepages/hugepages-${2}kB/nr_hugepages" 
    done
}

# Set Grub File to Static Method:
grubsm(){
    
    update_grub=$(config_fetching "Update Grub")

    grub_path="/etc/default/grub"
    grub_default="GRUB_CMDLINE_LINUX_DEFAULT=\"quiet splash\""
    
    argument_line_nr="$(awk "/GRUB_CMDLINE_LINUX_DEFAULT/"'{ print NR; exit }' ${grub_path})"
    default_arg="$(head -n ${argument_line_nr} ${grub_path} | tail -1 | awk "/GRUB_CMDLINE_LINUX_DEFAULT/"'{print}')"

    if [[ ${update_grub} == "yes" ]]; then
        grub_tuned="GRUB_CMDLINE_LINUX_DEFAULT=\"quiet splash isolcpus=${vCPU_PINNED} intel_iommu=on preempt=voluntary hugepagesz=1G hugepages=${VD_RAM} default_hugepagesz=1G transparent_hugepage=never\""
        if [[ ${default_arg} == ${grub_tuned} ]]; then #check if it is already in tunned mode
            echo "Already updated."
        else
            sudo sed -i "s/${default_arg}/${grub_tuned}/" ${grub_path}
            sudo update-grub && shutdown -r now
        fi
    elif [[ ${update_grub} == "no" ]]; then
        grub_tuned=$(cat ${grub_path} | grep "GRUB_CMDLINE_LINUX_DEFAULT=")
        if [[ ${default_arg} == ${grub_default} ]]; then # Check if it is already in default mode
            echo "Already default."
        else
            sudo sed -i "s/${grub_tuned}/${grub_default}/" ${grub_path}
            sudo update-grub && shutdown -r now
        fi
    fi
}

# LAUNCHER for VM
os_launch_tuned(){
    ################################ PART I ##############################
	echo "Launching VM..."
	# Set cpu as performance
	for file in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do 
        echo "performance" > $file
    done

    # Runnig in parallel process priority scheduler
	sched &

	# Sched_rt_runtime_us to 98%
	sysctl kernel.sched_rt_runtime_us=980000 >/dev/null
    
    # Call grub updater set the HugePages and run qemu with correct parameters
	page_size >/dev/null

    ################################ PART II ##############################
    # If cset gives you mount error is because newer version of Linux:
    # Just add this to the grub file: GRUB_CMDLINE_LINUX="systemd.unified_cgroup_hierarchy=0"
    # Creating isolated set to launch qemu
    sudo cset shield --cpu=${vCPU_PINNED} --threads --kthread=on >/dev/null 
    # Run VM the -d is to detect when windows boots
    sudo cset shield -e \
    qemu-system-x86_64 -- ${QEMU_ARGS[@]} -d trace:qcow2_writev_done_part 2> ${boot_logs_path} >/dev/null

    ################################ PART III ##############################
	# Free resources
	echo "Freeing resources..."
	# Back to 95% removing cset and freeing HP
	sysctl kernel.sched_rt_runtime_us=950000 >/dev/null
	delete_cset >/dev/null
	free_hugepages "${big_pages}" "${small_pages}" >/dev/null

	# Set cpu to powersave
	set_powersave(){
    for file in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do 
        echo "powersave" > $file
    done
	}

	# Remove boot file
	sudo rm -f ${boot_logs_path}
}

#####################################################################################################################################
##### MAIN #####
#####################################################################################################################################

main(){
	check_su
	set_variables
	os_launch_tuned

	echo "Exit success!"
}

#####################################################################################################################################
##### RUN #####
#####################################################################################################################################

main