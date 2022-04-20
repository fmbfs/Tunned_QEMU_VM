
#!/bin/bash

#
#
##################################################
#		Improvments to be done:
#		- Make a formula to automaticly calculate
#		the best cluster and l2_cache
##################################################
#
#
#

#RUN it as sudo su!

#------------------------------------------------------------------
#DEFAULTS
#x will print all
#set -euox pipefail
set -euo pipefail

# BASE_DIR is the path
BASE_DIR=$(dirname "${BASH_SOURCE[0]}")
[[ "${BASE_DIR}" == "." ]] && BASE_DIR=$(pwd)

#If no argument is passed we assume it to be launched pinned
ARG1="${1:--lp}"
ARG2="${2:-disk}"

#Args for CPU isolation and pinning
ARG3=($( ./host_check_group.sh | awk '{print $2}'))
ARG4=($( ./host_check_group.sh | awk '{print $3}'))

#--------------------------------------------------------------------
# FUNCTIONS

#print_error -- Error handler function
print_error(){
    echo "Error: $1"; exit 1
}

set_variables(){
	# OS .iso Paths
	ISO_DIR="${BASE_DIR}/Iso_Images/Windows"

	# Virtual disks (VD) path
	QEMU_VD="${BASE_DIR}/Virtual_Disks"

	# QEMU name and OS --> Windows 10
	OS_ISO="${ISO_DIR}/Win10_21H2_English_x64.iso"
	VD_NAME="${ARG2}.qcow2"
	OS_IMG="${QEMU_VD}/${VD_NAME}"

	# IMAGE
	Disk_Size="40G"
	Cluster_Size="64K"
	L2_Cache_Size="5M"
    # 1Mb for 8Gb using 64Kb

    # CACHE CLEAN IN SECONDS
	Cache_Clean_Interval="60"

	# RAM
    VD_RAM="8G"  

	# Pinned vCPU
	vCPU_PINNED="${ARG3},${ARG4}"

	# QEMU ARGUMENTS
	QEMU_ARGS=(
				"-name" "${ARG2}" \
				"-cpu" "max,kvm=off,hv_relaxed,hv_spinlocks=0x1fff,hv_vapic,hv_time" \
				"-enable-kvm" \
				"-mem-prealloc"\
				"-machine" "accel=kvm" \
				"-m" "${VD_RAM}" \
				"-rtc" "base=localtime,clock=host" \
				"-drive" "file=${OS_IMG},l2-cache-size=${L2_Cache_Size},cache=writethrough,cache-clean-interval=${Cache_Clean_Interval}" \
				#"-vga"  "virtio" \
				#"-display" "gtk,gl=on" 
			)
}

# HELP MENU
show_help(){
	echo ""
    echo "${0} [options]"
    echo "Options:"
    echo "  -i -----> Install the OS via CDROM"
    echo "  -c -----> Creates a qcow2 image for OS"
    echo "  -l -----> Launch qemu OS machine."
	echo "  -lp ----> Launch qemu OS machine with Pinned CPU."
	echo "  -a -----> Show QEMU args that are currently beeing deployed."
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
	"-lp")
		os_launch_tuned
		shift
		;;
	"-a")
		echo "qemu-system-x86_64 ${QEMU_ARGS[@]}"
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

# CHECK IF FILE ALREADY EXISTS
check_file(){
	# Scenario - File exists and is not a directory
	if test -f "${OS_IMG}";
	then
		echo "${OS_IMG} exists!"
		while true; 
		do
    		read -p "Do you want to overwrite? [y/n] " yn
    		case $yn in
        		[Yy]* ) echo "${OS_IMG} Overwritten!"; break;;
        		[Nn]* ) exit 0;;
        		* ) echo "Please answer yes or no.";;
    		esac
		done
	else
		echo "${OS_IMG} created!"
	fi
}

# CREATE VIRTUAL DISK IMAGE
create_image_os(){
	check_file
	echo "Creating Virtual Disk...";
	qemu-img create -f qcow2 -o cluster_size=${Cluster_Size},lazy_refcounts=on ${OS_IMG} ${Disk_Size}
	exit 1;
}

# LAUNCH QEMU-KVM
os_launch(){
	cd ${ISO_DIR}
	echo "Launching OS..."
    qemu-system-x86_64 ${QEMU_ARGS[@]}
	exit 1;
}

# RUN QEMU ARGS AND THEN FREE RESOURCES
run_qemu(){
	#run VM
	sudo cset shield -e \
	qemu-system-x86_64 -- ${QEMU_ARGS[@]}
	
	#free resources
	#back to 95% 
	sysctl kernel.sched_rt_runtime_us=950000
	delete_cset
	free_hugepages
}

# LAUNCH QEMU-KVM ISOLATED AND PINNED
os_launch_tuned(){
	source huge_pages_conf.sh
	source cset_conf.sh
	
	cd ${ISO_DIR}
	echo "Launching OS with pinned vCPU's --> ${vCPU_PINNED}..."
	#allocate resources
	page_size
	allocate_hugepages
	create_cset

	#sched_rt_runtime_us to 98%
	sysctl kernel.sched_rt_runtime_us=980000

	run_qemu &
	sleep 20

	cd ${BASE_DIR}
	source ./sched_fifo.sh
	sched
}

# INSTALL THE OPERATING SYSTEM N THE VIRTUAL MACHINE
os_install(){
	cd ${IMAGES_DIR}
	echo "Installing OS...";
	qemu-system-x86_64 ${QEMU_ARGS[@]} \
    -cdrom ${OS_ISO}
	exit 1;
}

#--------------------------------------------------------------------
# MAIN
set_variables
process_args