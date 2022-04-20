
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

# BASE_DIR is the path where .sh is
BASE_DIR=$(dirname "${BASH_SOURCE[0]}")
[[ "${BASE_DIR}" == "." ]] && BASE_DIR=$(pwd)

#if no argument is passed we assume it to be launched pinned
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

    # CACHE CLEAN IN SECONDS
	Cache_Clean_Interval="60"

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
	# Pinned vCPU
<<<<<<< HEAD
	vCPU_PINNED="7"
>>>>>>> testes
=======
	vCPU_PINNED="${ARG3},${ARG4}"
>>>>>>> testes

	# QEMU ARGUMENTS
	QEMU_ARGS=(
<<<<<<< HEAD
				"-name" "${ARGUMENT2}" \
				"-cpu" "max,hv_relaxed,hv_spinlocks=0x1fff,hv_vapic,hv_time" \
<<<<<<< HEAD
				"-smp" "cores=${CORES},threads=${THREADS}" \
=======
>>>>>>> testes
=======
				"-name" "${ARG2}" \
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
}

# HELP MENU
show_help(){
	echo ""
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
    echo "Options:"
<<<<<<< HEAD
    echo "  -i -> Install the OS via CDROM"
    echo "  -c -> Creates a qcow2 image for OS"
    echo "  -l -> Launch qemu OS machine."
	echo "  -lp -> Launch qemu OS machine with Pinned CPU."
    echo "  -h -> Show this help."
>>>>>>> testes
=======
    echo "  -i -----> Install the OS via CDROM"
    echo "  -c -----> Creates a qcow2 image for OS"
    echo "  -l -----> Launch qemu OS machine."
	echo "  -lp ----> Launch qemu OS machine with Pinned CPU."
	echo "  -a -----> Show QEMU args that are currently beeing deployed."
    echo "  -h -----> Show this help."
>>>>>>> testes
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
<<<<<<< HEAD
	"-osi")
		os_install
		shift
		;;
	"-osc")
		create_image_os
		shift
		;;
	"-osl")
		os_launch
		shift
		;;
	"-help")
=======
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
		os_launch_pinned
		shift
		;;
	"-a")
		echo "qemu-system-x86_64 ${QEMU_ARGS[@]}"
		shift
		;;
	"-h")
>>>>>>> testes
		show_help
		shift
		;;
	*)
<<<<<<< HEAD
		echo "Unrecognised option"
=======
		echo "Unrecognised option. -h for help."
>>>>>>> testes
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
}

#RUN QEMU ARGS AND THEN FREE RESOURCES
run_qemu(){
	#run VM
	sudo cset shield -e \
	qemu-system-x86_64 -- ${QEMU_ARGS[@]}
	
	#free resources
	#the sleep may or maynot be needed
	sleep 5
	delete_cset
	free_hugepages
}

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

	run_qemu &
	sleep 20

	cd ${BASE_DIR}
	source ./sched_fifo.sh
	sched
>>>>>>> testes
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