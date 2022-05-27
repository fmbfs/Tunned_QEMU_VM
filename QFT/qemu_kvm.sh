#!/bin/bash

###########################################################################
#DEFAULTS
#x will print all
#set -euox pipefail
set -euo pipefail

#trap for debug
trap(){
	echo "trap trap trap!!!!!!"
}

# Defining Colors for text output
red=$( tput setaf 1 );
yellow=$( tput setaf 3 );
green=$( tput setaf 2 );
normal=$( tput sgr 0 );

#check for sudo su
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

#look at this for just enable sudo when needed
#read -s -p "Enter Sudo Password: " PASSWORD
#echo $PASSWORD | sudo -S

###########################################################################
#SOURCES
source huge_pages_conf.sh
source host_check_group.sh
source cset_conf.sh
source sched_fifo.sh
source cpu_freq.sh
source structure_check.sh

BASE_DIR=$(dirname "${BASH_SOURCE[0]}")
[[ "${BASE_DIR}" == "." ]] && BASE_DIR=$(pwd)

# If no argument is passed we assume it to be launched pinned
ARG1="${1:--lt}"
ARG2="${2:-disk}"

# Args for CPU isolation and pinning
ARG3="${3:-${group[0]}}"
ARG4="${4:-${group[1]}}"

# Defining Global Variable
L2_Cache_Size=""

# Boot Logs file
boot_logs_path="${BASE_DIR}/boot_logs.txt"

###########################################################################
# FUNCTIONS

set_variables(){
	# OS .iso Paths
	ISO_DIR="${BASE_DIR}/Iso_Images/Windows"

	# Virtual disks (VD) path
	QEMU_VD="${BASE_DIR}/Virtual_Disks"

	# QEMU name and OS --> Windows 10
	OS_ISO="${ISO_DIR}/Win10_*.iso"
	VD_NAME="${ARG2}.qcow2"
	OS_IMG="${QEMU_VD}/${VD_NAME}"
	
	# Calls function to process clusters
	process_cluster
	
	# Cores and Threads
	CORES="2"
	THREADS="4"

    # CACHE CLEAN IN SECONDS
	Cache_Clean_Interval="60"

	# Pinned vCPU
	vCPU_PINNED="${ARG3},${ARG4}"

	# Common Args
	QEMU_ARGS=(
				"-name" "${ARG2}" \
				"-enable-kvm" \
				"-m" "${VD_RAM}G" \
				#"-vga"  "virtio" \
				#"-vga"  "none" \
				#"-display" "gtk,gl=on" \		 
	)

	# Specific Args
	if [ ${ARG1} == "-lt" ]; then
		QEMU_ARGS+=(
			"-cpu" "host,pdpe1gb,kvm=off,hv_relaxed,hv_spinlocks=0x1fff,hv_vapic,hv_time" \
			"-m" "${VD_RAM}G" \
			"-mem-path" "/dev/hugepages" \
			"-mem-prealloc" \
			"-machine" "accel=kvm,kernel_irqchip=on" \
			"-rtc" "base=localtime,clock=host" \
			"-drive" "file=${OS_IMG},l2-cache-size=${L2_Cache_Size},cache=writethrough,cache-clean-interval=${Cache_Clean_Interval}" \
		)
	elif [ ${ARG1} == "-l" ]; then
		QEMU_ARGS+=(
			"-cpu" "max" \
			"-smp" "cores=${CORES},threads=${THREADS}" \
			"-drive" "file=${OS_IMG}"
		)
	elif [ ${ARG1} == "-i" ]; then
		QEMU_ARGS+=(
			"-cpu" "max" \
			"-smp" "cores=${CORES},threads=${THREADS}" \
			"-drive" "file=${OS_IMG}" \
    		"-cdrom" "${OS_ISO}"
		)
	fi
}

# Process Cluster Sizes
process_cluster(){
	# IMAGE
	Disk_Size="${5:-40}"
	Cluster_Size="${6:-64}K"
	L2_calculated=0
	# 1Mb for 8Gb using 64Kb. Make it cluster size fit no decimals.
	# The value that is beeing divided by is the range that 1Mb of that 
	# cluster size can reach
	case "${Cluster_Size}" in
	"")
		echo "No arguments provided,check below. "
		shift
		;;
	"64K")
		L2_calculated=$(( ${Disk_Size}/8 + 1 ))
		;;
	"128K")
		L2_calculated=$(( ${Disk_Size}/16 + 1 ))
		;;
	"256K")
		L2_calculated=$(( ${Disk_Size}/32 + 1 ))
		;;
	"512K")
		L2_calculated=$(( ${Disk_Size}/64 + 1 ))
		;;
	"1024K")
		L2_calculated=$(( ${Disk_Size}/128 + 1 ))
		;;
	"2048K")
		L2_calculated=$(( ${Disk_Size}/256 + 1 ))
		;;
	*)
		echo "Unrecognised option. -h for help."
		shift
		;;
	esac

	L2_Cache_Size="${L2_calculated}M"
}

# HELP MENU
show_help(){
	echo ""
    echo "${0} [OPTION] [VSD NAME] [RAM GiB] [CPU ISOL A] [CPU ISOL B] [VSD GiB] [CLUSTER SIZE KiB]"
    echo "Options:"
    echo "  -i -----> Install the OS via CDROM"
    echo "  -c -----> Creates a qcow2 image for OS"
    echo "  -l -----> Launch qemu OS machine."
	echo "  -lt ----> Launch qemu OS machine with Pinned CPU."
    echo "  -h -----> Show this help."
    echo ""
    exit 0
}

# SWITHC ARGUMENTS
process_args(){
	case "${ARG1}" in
	"")
		echo "No arguments provided,check below. "
		show_help
		shift
		;;
	"-i")
		os_install
		shift
		;;
	"-c")
		create_image_os
		shift
		;;
	"-l")
		os_launch
		shift
		;;
	"-lt")
		check_su
		os_launch_tuned
		shift
		;;
	"-h")
		show_help
		shift
		;;
	*)
		echo "Unrecognised option. -h for help."
		shift
		;;
	esac	
}

# CREATE VIRTUAL DISK IMAGE
create_image_os(){
	# CHECK STRUCTURE
	check_dir ${ISO_DIR}
	check_dir ${QEMU_VD}
	check_file ${OS_IMG}
	
	echo "Creating Virtual Hard Drive...";
	qemu-img create -f qcow2 -o cluster_size=${Cluster_Size},lazy_refcounts=on ${OS_IMG} ${Disk_Size}G
}

# LAUNCH QEMU-KVM
os_launch(){
	echo "Launching untuned VM..."
	qemu-system-x86_64 ${QEMU_ARGS[@]}	
}

# LAUNCH QEMU-KVM ISOLATED AND PINNED
os_launch_tuned(){
	echo "Launching tunned VM..."
	#set cpu as performance
	set_performance

	#allocate resources
	page_size >/dev/null
	create_cset >/dev/null

	#sched_rt_runtime_us to 98%
	#https://www.kernel.org/doc/html/latest/scheduler/sched-rt-group.html ver isto
	sysctl kernel.sched_rt_runtime_us=980000 >/dev/null

	#runnig in parallel
	sched &
	
	# RUN QEMU ARGS AND THEN FREE RESOURCES
	#run VM the -d is to detect when windows boots
	sudo cset shield -e \
	qemu-system-x86_64 -- ${QEMU_ARGS[@]} -d trace:qcow2_writev_done_part 2> ${boot_logs_path} >/dev/null
	
	#free resources
	#back to 95% 
	sysctl kernel.sched_rt_runtime_us=950000 >/dev/null
	delete_cset >/dev/null
	free_hugepages "${big_pages}" "${small_pages}" >/dev/null

	#set cpu to ondemand
	set_powersave

	#remove boot file
	sudo rm -f ${boot_logs_path}
}

# INSTALL THE OPERATING SYSTEM N THE VIRTUAL MACHINE
os_install(){
	echo "Installing OS on ${ARG2}...";
	qemu-system-x86_64 ${QEMU_ARGS[@]}
}

###########################################################################
# MAIN

set_variables
process_args