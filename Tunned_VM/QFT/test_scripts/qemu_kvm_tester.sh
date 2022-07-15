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
source cset_conf.sh
source sched_fifo.sh
source cpu_freq.sh

BASE_DIR=$(dirname "${BASH_SOURCE[0]}")
[[ "${BASE_DIR}" == "." ]] && BASE_DIR=$(pwd)

# If no argument is passed we assume it to be launched pinned
ARG1="${1:--lt}"
ARG2="${2:-disk}"

# Defining Global Variable
L2_CACHE_SIZE=""

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
	CCLEAN_INTERVAL="60"

	# Pinned vCPU
	VCPU_PINNED=$(cat /sys/devices/system/cpu/cpu*/topology/thread_siblings_list | sort | uniq | tail -1)

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
			"-cpu" "max,pdpe1gb,kvm=off,hv_relaxed,hv_spinlocks=0x1fff,hv_vapic,hv_time" \
			"-m" "${VD_RAM}G" \
			"-mem-path" "/dev/hugepages" \
			"-mem-prealloc" \
			"-machine" "accel=kvm,kernel_irqchip=on" \
			"-rtc" "base=localtime,clock=host" \
			"-drive" "file=${OS_IMG},l2-cache-size=${L2_CACHE_SIZE},cache=writethrough,cache-clean-interval=${CCLEAN_INTERVAL}" \
		)
	elif [ ${ARG1} == "-l" ]; then
		QEMU_ARGS+=(
			"-cpu" "host" \
			"-smp" "cores=${CORES},threads=${THREADS}" \
			"-drive" "file=${OS_IMG}"
		)
	elif [ ${ARG1} == "-i" ]; then
		QEMU_ARGS+=(
			"-cpu" "host" \
			"-smp" "cores=${CORES},threads=${THREADS}" \
			"-drive" "file=${OS_IMG}" \
			"-cdrom" "${OS_ISO}"
		)
	fi
}

# Process Cluster Sizes
process_cluster(){
	# IMAGE
	DISK_SIZE="${5:-40}"
	CS_VALUE="${6:-64}"
	CLUTER_SIZE="${CS_VALUE}K"
	L2_CALCULATED=0
	# 1Mb for 8Gb using 64Kb. Make it cluster size fit no decimals.
	# The value that is beeing divided by is the range that 1Mb of that 
	# cluster size can reach
	ARR_CS_VALID=("64","128","256","512","1024","2048")
	if [[ "${ARR_CS_VALID[@]}" =~ "${CS_VALUE}" ]]; then
		auxiliar_calc=$(( ${CS_VALUE}/8 ))
		L2_CALCULATED=$(( ${DISK_SIZE}/${auxiliar_calc} + 1 ))
		#echo "${auxiliar_calc}"
		#echo "${L2_CALCULATED}"
		#exit 0
	else
		echo "Invalid Cluster Size."
		exit 1
	fi

	L2_CACHE_SIZE="${L2_CALCULATED}M"
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
	echo "Creating Virtual Hard Drive...";
	qemu-img create -f qcow2 -o CLUTER_SIZE=${CLUTER_SIZE},lazy_refcounts=on ${OS_IMG} ${DISK_SIZE}G
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
main(){
	set_variables
	process_args
}

###########################################################################
# RUN
main