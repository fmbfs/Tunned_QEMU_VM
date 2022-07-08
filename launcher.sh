#!/bin/bash

#####################################################################################################################################
##### DEFAULTS #####
#####################################################################################################################################

# Defining Colors for text output
red=$( tput setaf 1 );
yellow=$( tput setaf 3 );
normal=$( tput sgr 0 );

# Defining base PATH
BASE_DIR=$(dirname "${BASH_SOURCE[0]}")
[[ "${BASE_DIR}" == "." ]] && BASE_DIR=$(pwd)

# If no argument is passed we assume it to be launched pinned
read -p "${red}Name your VSD ${yellow}[disk]${red}: ${normal}" ARG1
ARG1="${ARG1:-disk}" #VARIVAVEL ESCOLHA

# RAM for VM
read -p "${red}Set your RAM in GiB ${yellow}[10]${red}: ${normal}" VD_RAM
VD_RAM="${VD_RAM:-10}" #VARIVAVEL ESCOLHA

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
	ISO_DIR="${BASE_DIR}/Tunned_VM/QFT/Iso_Images/Windows"

	# Virtual disks (VD) path
	QEMU_VD="${BASE_DIR}/Tunned_VM/QFT/Virtual_Disks"

	# QEMU name and OS --> Windows 10
	OS_ISO="${ISO_DIR}/Tunned_VM/QFT/Win10_*.iso"
	VD_NAME="${ARG1}.qcow2"
	OS_IMG="${QEMU_VD}/${VD_NAME}"

	# Process clusters
	process_cluster

    # CACHE CLEAN IN SECONDS
    read -p "${red}Set your Interval for cache clean in sec. ${yellow}[60]${red}: ${normal}" Cache_Clean_Interval
	Cache_Clean_Interval="${Cache_Clean_Interval:-60}" #VARIVAVEL ESCOLHA

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
                    # get parent PID of QEMU VM                                
                    PARENT_PID=$(pstree -pa $(pidof qemu-system-x86_64) | grep ${ARG1} | cut -d','  -f2 | cut -d' ' -f1)
                    # set all threads of parent PID to SCHED_FIFO 99 priority
                    pstree -pa $PARENT_PID | cut -d','  -f2 | cut -d' ' -f1 | xargs -L1 echo "chrt -f -p 99" | bash
                    #echo "Changing to highest priority (99) done!"
                    exit 0
                fi
            done < ${boot_logs_path}
        fi
    done 
}

# Process Cluster Sizes
process_cluster(){
    arr_cs_valid=("64","128","256","512","1024","2048")
	# Virtual Storage Device
    read -p "${red}Set your created VSD size in GiB ${yellow}[40]${red}: ${normal}" Disk_Size
	Disk_Size="${Disk_Size:-40}"
    read -p "${red}Set your VSD Cluster size in KiB ${yellow}[64]${red}. Possible values [${arr_cs_valid[@]}]: ${normal}" cluster_size_value
	cluster_size_value="${cluster_size_value:-64}"
	Cluster_Size="${cluster_size_valnue}K"
	L2_calculated=0
	if [[ "${arr_cs_valid[@]}" =~ "${cluster_size_value}" ]]; then
		auxiliar_calc=$(( ${cluster_size_value}/8 ))
		L2_calculated=$(( ${Disk_Size}/${auxiliar_calc} + 1 ))
	else
		echo "Invalid Cluster Size."
        read -p "${red}Set your VSD Cluster Size in KiB ${yellow}[64]${red}. Possible values [${arr_cs_valid[@]}]: ${normal}" cluster_size_value
	fi
	L2_Cache_Size="${L2_calculated}M"
}

# Huge Pages set-up.
page_size(){
    # Total page calculation
    total_pages=$(( ${VD_RAM} * ${big_pages} / ${small_pages} ))
    # Big pages
    if [ "$(grep Hugepagesize /proc/meminfo | awk '{print $2}')" = "${big_pages}" ]; then
        hugepages "${big_pages}" "${VD_RAM}"
    else
        read -p "Update Grub (${red}reboot and rerun is needed${yellow})? (yes/no) ${normal}" yn
        case $yn in 
            yes ) 
                grubsm tuned isolcpus;;
            no ) 
                # Small pages
                if [ "$(grep Hugepagesize /proc/meminfo | awk '{print $2}')" = "${small_pages}" ]; then 
                    hugepages "${small_pages}" "${total_pages}"
                else
                    print_error "HP_2 - ${small_pages} Not avalilable"
                fi;;
            * ) 
                echo "Invalid response. Type 'yes' or 'no'.";
                exit 1;;
        esac
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
}

# Set Grub File to Static Method:
grubsm(){
    grub_path="/etc/default/grub"
    grub_default="GRUB_CMDLINE_LINUX_DEFAULT=\"quiet splash\""
    if [[ ${1} == "tuned" ]]; then
        if [[ ${2} =~ "isolcpus" ]]; then
            grub_isol="isolcpus=${vCPU_PINNED}"
        else
            grub_isol=""
        fi
        grub_tuned="GRUB_CMDLINE_LINUX_DEFAULT=\"quiet splash ${grub_isol} intel_iommu=on preempt=voluntary hugepagesz=1G hugepages=${VD_RAM} default_hugepagesz=1G transparent_hugepage=never\""
        sudo sed -i "s/${grub_default}/${grub_tuned}/" ${grub_path}
    else
        grub_tuned=$(cat ${grub_path} | grep "GRUB_CMDLINE_LINUX_DEFAULT=")
        sudo sed -i "s/${grub_tuned}/${grub_default}/" ${grub_path}
    fi
    sudo update-grub && echo "${yellow}Rebooting..." && shutdown -r now
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

    # Check Grub default or not
    read -p "Set default Grub (${red}reboot is needed${yellow})? (yes/no) ${normal}" yn
        case $yn in 
            yes )
                grubsm;;
            no )    
                echo "${yellow}Exit success!";
                exit 1;;
            * ) 
                echo "invalid response. Type 'yes' or 'no'.";
                exit 1;;
        esac
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