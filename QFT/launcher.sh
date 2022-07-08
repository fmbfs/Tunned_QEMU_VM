#!/bin/bash

#####################################################################################################################################
##### DEFAULTS #####
#####################################################################################################################################

# Defining Colors for text output
red=$( tput setaf 1 );
yellow=$( tput setaf 3 );
normal=$( tput sgr 0 );

BASE_DIR=$(dirname "${BASH_SOURCE[0]}")
[[ "${BASE_DIR}" == "." ]] && BASE_DIR=$(pwd)

# If no argument is passed we assume it to be launched pinned
ARG1="${1:--lt}"
ARG2="${2:-disk}"

# RAM for VM
VD_RAM="${3:-10}"

# Defining Global Variable
big_pages="1048576"
small_pages="2048"

# Boot Logs file
boot_logs_path="${BASE_DIR}/boot_logs.txt"

#####################################################################################################################################
##### FUNCTIONS #####
#####################################################################################################################################

# Check for sudo su
check_su(){
	if [[ ${UID} != 0 ]]; then
		echo "${red}
		This script must be run as sudo permissions.
			Please run it as: 
				${normal}sudo su ${0}
		"
		exit 1
	fi
}

set_variables(){
	# OS .iso Paths
	ISO_DIR="${BASE_DIR}/Iso_Images/Windows"

	# Virtual disks (VD) path
	QEMU_VD="${BASE_DIR}/Virtual_Disks"

	# QEMU name and OS --> Windows 10
	OS_ISO="${ISO_DIR}/Win10_*.iso"
	VD_NAME="${ARG2}.qcow2"
	OS_IMG="${QEMU_VD}/${VD_NAME}"

	# Process clusters
	process_cluster

    # CACHE CLEAN IN SECONDS
	Cache_Clean_Interval="60"

	# Pinned vCPU
	vCPU_PINNED=$(cat /sys/devices/system/cpu/cpu*/topology/thread_siblings_list | sort | uniq | tail -1)

	# Common Args
	QEMU_ARGS=(
				"-name" "${ARG2}" \
				"-enable-kvm" \
				"-m" "${VD_RAM}G" \	 
	)

	# Specific Args
	QEMU_ARGS+=(
		"-cpu" "max,pdpe1gb,kvm=off,hv_relaxed,hv_spinlocks=0x1fff,hv_vapic,hv_time" \
		"-m" "${VD_RAM}G" \
		"-mem-path" "/dev/hugepages" \
		"-mem-prealloc" \
		"-machine" "accel=kvm,kernel_irqchip=on" \
		"-rtc" "base=localtime,clock=host" \
		"-drive" "file=${OS_IMG},l2-cache-size=${L2_Cache_Size},cache=writethrough,cache-clean-interval=${Cache_Clean_Interval}" \
	)
}

# HELP MENU
show_help(){
	echo ""
    echo "${0} [OPTION] [VSD NAME] [RAM GiB] [CPU ISOL A] [CPU ISOL B] [VSD GiB] [CLUSTER SIZE KiB]"
    echo "Option:"
	echo "  -lt ----> Launch qemu OS machine with Pinned CPU."
    echo "  -h -----> Show this help."
    echo ""
    exit 0
}

# LAUNCH QEMU-KVM ISOLATED AND PINNED
os_launch_tuned(){
	echo "${yellow}Launching tunned VM..."
	# Set cpu as performance
	for file in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
    do 
        echo "performance" > $file
    done
	
	# Allocate resources
	page_size >/dev/null
	sudo cset shield --cpu=${vCPU_PINNED} --threads --kthread=on >/dev/null

	# Sched_rt_runtime_us to 98%
	sysctl kernel.sched_rt_runtime_us=980000 >/dev/null

	# Runnig in parallel
	sched &
	
	# RUN QEMU ARGS AND THEN FREE RESOURCES
	# Run VM the -d is to detect when windows boots
	sudo cset shield -e \
	qemu-system-x86_64 -- ${QEMU_ARGS[@]} -d trace:qcow2_writev_done_part 2> ${boot_logs_path} >/dev/null
	
	
	# Free resources
	echo "${yellow}Freeing resources..."
	# Back to 95% removing cset and freeing HP
	sysctl kernel.sched_rt_runtime_us=950000 >/dev/null
	delete_cset >/dev/null
	free_hugepages "${big_pages}" "${small_pages}" >/dev/null

	# Set cpu to powersave
	set_powersave(){
    for file in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
    do 
        echo "powersave" > $file
    done
	}

	# Remove boot file
	sudo rm -f ${boot_logs_path}
}

# Delete_cset
delete_cset(){
    sudo cset set -d system
    while [[ $(sudo cset set -d system) =~ "done" ]] 
    do 
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
                    PARENT_PID=$(pstree -pa $(pidof qemu-system-x86_64) | grep ${ARG2} | cut -d','  -f2 | cut -d' ' -f1)
                    # Set all threads of parent PID to SCHED_FIFO 99 priority
                    pstree -pa $PARENT_PID | cut -d','  -f2 | cut -d' ' -f1 | xargs -L1 echo "chrt -f -p 99" | bash
                    # Echo "Changing to highest priority (99) done!"
                    exit 0
                fi
            done < ${boot_logs_path}
        fi
    done 
}

# Process Cluster Sizes
process_cluster(){
	# Virtual Storage Device
	Disk_Size="${5:-40}"
	cluster_size_value="${6:-64}"
	Cluster_Size="${cluster_size_value}K"
	L2_calculated=0

	arr_cs_valid=("64","128","256","512","1024","2048")
	if [[ "${arr_cs_valid[@]}" =~ "${cluster_size_value}" ]]; then
		auxiliar_calc=$(( ${cluster_size_value}/8 ))
		L2_calculated=$(( ${Disk_Size}/${auxiliar_calc} + 1 ))
	else
		echo "Invalid Cluster Size."
		exit 1
	fi

	L2_Cache_Size="${L2_calculated}M"
}

# It is recommended to use the largest supported hugepage size for the best performance.
page_size(){
    # Total page calculation
    total_pages=$(( ${VD_RAM} * ${big_pages} / ${small_pages} ))
    # Big pages
    if [ "$(grep Hugepagesize /proc/meminfo | awk '{print $2}')" = "${big_pages}" ]; then
        hugepages "${big_pages}" "${VD_RAM}"
        echo "HP_1 - ${big_pages} OK"
    else
        echo "HP_1 - ${big_pages} Not avalilable"
        # Small pages
        if [ "$(grep Hugepagesize /proc/meminfo | awk '{print $2}')" = "${small_pages}" ]; then 
                hugepages "${small_pages}" "${total_pages}"
                echo "HP_2 - ${small_pages} OK"
        else
            print_error "HP_2 - ${small_pages} Not avalilable"
        fi      
    fi
}

# Allocate huge pages size
hugepages(){
    sysctl -w vm.nr_hugepages="${2}"

    # Disable THP 
    echo "never" > "/sys/kernel/mm/transparent_hugepage/enabled"
    echo "never" > "/sys/kernel/mm/transparent_hugepage/defrag"
    
    for i in $(find /sys/devices/system/node/node* -maxdepth 0 -type d);
    do
        echo "${2}" > "$i/hugepages/hugepages-${1}kB/nr_hugepages"    
    done
    echo "HugePages - ${1} - successfully enabled!"
}

# Free allocated huge pages size
free_hugepages(){
    sysctl -w vm.nr_hugepages="0"

    # Enable THP
    echo "always" > "/sys/kernel/mm/transparent_hugepage/enabled"
    echo "always" > "/sys/kernel/mm/transparent_hugepage/defrag"

    for i in $(find /sys/devices/system/node/node* -maxdepth 0 -type d);
    do
        echo 0 > "$i/hugepages/hugepages-${1}kB/nr_hugepages"
        echo 0 > "$i/hugepages/hugepages-${2}kB/nr_hugepages" 
    done
    echo "HugePages successfully disabled."
}

#####################################################################################################################################
##### MAIN #####
#####################################################################################################################################

main(){
	check_su
	set_variables
	os_launch_tuned
	echo "${yellow}Exit success!"
}

#####################################################################################################################################
##### RUN #####
#####################################################################################################################################
main