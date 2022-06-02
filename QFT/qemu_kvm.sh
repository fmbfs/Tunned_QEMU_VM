#!/bin/bash

#------------------------------------------------------------------
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

#------------------------------------------------------------------
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

<<<<<<< .merge_file_viOe8x

#------------------------------------------------------------------
=======
###########################################################################
>>>>>>> .merge_file_wJxmdE
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
<<<<<<< HEAD
<<<<<<< HEAD

<<<<<<< HEAD
    # Processor
    CORES="4"
	THREADS="2"
<<<<<<< HEAD
=======
	#-smp 2 cores=${CORES},threads=${THREADS} there is no need.

>>>>>>> testes
=======
>>>>>>> testes
	# IMAGE
	Disk_Size="40G"
	Cluster_Size="64K"
	L2_Cache_Size="5M"
    # 1Mb for 8Gb using 64Kb
=======
=======
>>>>>>> 97aada6024f660bf61a0b753c77897af7506945c
	
	# Calls function to process clusters
	process_cluster
	
	# Cores and Threads
	CORES="2"
	THREADS="4"
<<<<<<< HEAD
>>>>>>> testes
=======
>>>>>>> 97aada6024f660bf61a0b753c77897af7506945c

    # CACHE CLEAN IN SECONDS
	Cache_Clean_Interval="60"

<<<<<<< HEAD
<<<<<<< HEAD
	# RAM
    VD_RAM="8G"  

<<<<<<< HEAD
	#Pinned CPU
<<<<<<< HEAD
	CPU_PINNED="7"
=======
	CPU_PINNED="3,7"
>>>>>>> testes
=======
=======
>>>>>>> testes
=======
>>>>>>> 97aada6024f660bf61a0b753c77897af7506945c
	# Pinned vCPU
	vCPU_PINNED="${ARG3},${ARG4}"

	# Common Args
	QEMU_ARGS=(
				"-name" "${ARG2}" \
<<<<<<< HEAD
<<<<<<< HEAD
				"-cpu" "max,kvm=off,hv_relaxed,hv_spinlocks=0x1fff,hv_vapic,hv_time" \
>>>>>>> testes
				"-enable-kvm" \
				"-mem-prealloc"\
				"-machine" "accel=kvm" \
				"-m" "${VD_RAM}" \
				"-rtc" "base=localtime,clock=host" \
				"-drive" "file=${OS_IMG},l2-cache-size=${L2_Cache_Size},cache=writethrough,cache-clean-interval=${Cache_Clean_Interval}" \
<<<<<<< HEAD
=======
				#"-vga"  "virtio" \
				#"-display" "gtk,gl=on" 
>>>>>>> testes
			)
=======
=======
>>>>>>> 97aada6024f660bf61a0b753c77897af7506945c
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
			"-drive" "file=${OS_IMG},l2-cache-size=${L2_Cache_Size},cache=writethrough,cache-clean-interval=${Cache_Clean_Interval}" \
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
	Disk_Size="${5:-40}"
	cluster_size_value="${6:-64}"
	Cluster_Size="${cluster_size_value}K"
	L2_calculated=0
	# 1Mb for 8Gb using 64Kb. Make it cluster size fit no decimals.
	# The value that is beeing divided by is the range that 1Mb of that 
	# cluster size can reach
	arr_cs_valid=("64","128","256","512","1024","2048")
	if [[ "${arr_cs_valid[@]}" =~ "${cluster_size_value}" ]]; then
		auxiliar_calc=$(( ${cluster_size_value}/8 ))
		L2_calculated=$(( ${Disk_Size}/${auxiliar_calc} + 1 ))
		#echo "${auxiliar_calc}"
		#echo "${L2_calculated}"
		#exit 0
	else
		echo "Invalid Cluster Size."
		exit 1
	fi

	L2_Cache_Size="${L2_calculated}M"
<<<<<<< HEAD
>>>>>>> testes
=======
>>>>>>> 97aada6024f660bf61a0b753c77897af7506945c
}

# HELP MENU
show_help(){
	echo ""
<<<<<<< HEAD
<<<<<<< HEAD
<<<<<<< HEAD
<<<<<<< HEAD
    echo "./create_system.sh [options]"
    echo "Options:"
    echo "  -osi -> Install the OS via CDROM"
    echo "  -osc -> Creates a qcow2 image for OS"
    echo "  -osl -> Launch qemu OS machine."
    echo "  -help -> Show this help."
=======
    echo "./qemu_kvm.sh [options]"
=======
    echo "${0} [options]"
>>>>>>> testes
=======
    echo "${0} [OPTION] [VSD NAME] [RAM GiB] [CPU ISOL A] [CPU ISOL B] [VSD GiB] [CLUSTER SIZE KiB]"
>>>>>>> testes
=======
    echo "${0} [OPTION] [VSD NAME] [RAM GiB] [CPU ISOL A] [CPU ISOL B] [VSD GiB] [CLUSTER SIZE KiB]"
>>>>>>> 97aada6024f660bf61a0b753c77897af7506945c
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
<<<<<<< HEAD
<<<<<<< HEAD
	cd ${ISO_DIR}
	echo "Launching OS..."
<<<<<<< HEAD
<<<<<<< HEAD
    echo "$QEMU_ARGS"
	#hexadecimal afinity for cpu placement
    taskset -c $CPU_PINNED \
    qemu-system-x86_64 $QEMU_ARGS
=======
    echo "${QEMU_ARGS[@]}"
=======
>>>>>>> testes
    qemu-system-x86_64 ${QEMU_ARGS[@]}
	exit 1;
=======
	echo "Launching untuned VM..."
	qemu-system-x86_64 ${QEMU_ARGS[@]}	
>>>>>>> testes
=======
	echo "Launching untuned VM..."
	qemu-system-x86_64 ${QEMU_ARGS[@]}	
>>>>>>> 97aada6024f660bf61a0b753c77897af7506945c
}

<<<<<<< .merge_file_viOe8x
	qemu-system-x86_64 ${QEMU_ARGS[@]}	
}
=======
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
>>>>>>> .merge_file_wJxmdE

	#runnig in parallel
	sched &
	
	# RUN QEMU ARGS AND THEN FREE RESOURCES
	#run VM the -d is to detect when windows boots
	sudo cset shield -e \
	qemu-system-x86_64 -- ${QEMU_ARGS[@]} -d trace:qcow2_writev_done_part 2> ${boot_logs_path} >/dev/null
	
	#free resources
<<<<<<< HEAD
	#the sleep may or maynot be needed
	sleep 5
	delete_cset
	free_hugepages
}

<<<<<<< HEAD
# LAUNCH QEMU-KVM ISOLATED AND PINNED
os_launch_pinned(){
	source huge_pages_conf.sh
	source cset_conf.sh
	
	cd ${ISO_DIR}
	echo "Launching OS with pinned vCPU --> ${vCPU_PINNED}..."
<<<<<<< HEAD
    echo "QEMU arguments: ${QEMU_ARGS[@]}"
	echo " "
	#only use when 2 cpus are needed
    #sudo chrt -r 1 \
<<<<<<< HEAD
	taskset -c ${vCPU_PINNED} \
    qemu-system-x86_64 ${QEMU_ARGS[@]}
>>>>>>> testes
	exit 1;
=======
	#taskset -c ${vCPU_PINNED} \
	create_cset
	echo " "
	sudo cset shield -e \
	qemu-system-x86_64 -- ${QEMU_ARGS[@]}
	echo " "
	delete_cset
	#exit 1;
>>>>>>> testes
=======
	#allocate resources
	page_size
	allocate_hugepages
	create_cset
=======
	#back to 95% 
	sysctl kernel.sched_rt_runtime_us=950000 >/dev/null
	delete_cset >/dev/null
	free_hugepages "${big_pages}" "${small_pages}" >/dev/null
>>>>>>> testes

	#set cpu to ondemand
	set_powersave

<<<<<<< HEAD
	cd ${BASE_DIR}
	source ./sched_fifo.sh
	sched
>>>>>>> testes
=======
	#remove boot file
	sudo rm -f ${boot_logs_path}
>>>>>>> testes
=======
	#set cpu to ondemand
	set_powersave

	#remove boot file
	sudo rm -f ${boot_logs_path}
>>>>>>> 97aada6024f660bf61a0b753c77897af7506945c
}

# INSTALL THE OPERATING SYSTEM N THE VIRTUAL MACHINE
os_install(){
	echo "Installing OS on ${ARG2}...";
	qemu-system-x86_64 ${QEMU_ARGS[@]}
}

#------------------------------------------------------------------
# MAIN

<<<<<<< HEAD
set_variablesgit

# CHECK STRUCTURE
#check_dir ${ISO_DIR}
#check_dir ${QEMU_VD}
#check_file ${OS_IMG}

=======
set_variables
<<<<<<< HEAD

# CHECK STRUCTURE
#check_dir ${ISO_DIR}
#check_dir ${QEMU_VD}
#check_file ${OS_IMG}

<<<<<<< .merge_file_viOe8x
process_args
=======
=======
>>>>>>> testes
>>>>>>> 97aada6024f660bf61a0b753c77897af7506945c
process_args
>>>>>>> .merge_file_wJxmdE
