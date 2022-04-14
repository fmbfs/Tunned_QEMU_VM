
#
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

#--------------------------------------------------------------------
#!/bin/bash

# Default
#BASE_DIR is the path where .sh is
BASE_DIR="${PWD}"
ARGUMENT1="$1"
ARGUMENT2="$2"

#--------------------------------------------------------------------
#FUNCTIONS

set_variables(){
	#OS .iso Paths
	IMAGES_DIR="${BASE_DIR}/Iso_Images/Windows"

	#Virtual disks (VD) path
	QEMU_VD="${BASE_DIR}/Virtual_Disks"

	## QEMU name and OS --> Windows 10
	OS_ISO="${IMAGES_DIR}/Win10_21H2_English_x64.iso"
	VD_NAME="${ARGUMENT2}.qcow2"
	OS_IMG="${QEMU_VD}/${VD_NAME}"

    # Processor
    CORES="4"
	THREADS="2"
<<<<<<< HEAD
=======
	#-smp 2 cores=${CORES},threads=${THREADS} there is no need.

>>>>>>> testes
	# IMAGE
	Disk_Size="40G"
	Cluster_Size="64K"
	L2_Cache_Size="5M"
    #1Mb for 8Gb using 64Kb
    #CACHE CLEAN IN SECONDS
	Cache_Clean_Interval="60"
	 # RAM
    VD_RAM="8G"  

	#Pinned CPU
<<<<<<< HEAD
	CPU_PINNED="7"
=======
	CPU_PINNED="3,7"
>>>>>>> testes

	#QEMU ARGUMENTS
	QEMU_ARGS=(
				"-name" "${ARGUMENT2}" \
				"-cpu" "max,hv_relaxed,hv_spinlocks=0x1fff,hv_vapic,hv_time" \
<<<<<<< HEAD
				"-smp" "cores=${CORES},threads=${THREADS}" \
=======
>>>>>>> testes
				"-enable-kvm" \
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

#HELP MENU
show_help(){
	echo ""
<<<<<<< HEAD
    echo "./create_system.sh [options]"
    echo "Options:"
    echo "  -osi -> Install the OS via CDROM"
    echo "  -osc -> Creates a qcow2 image for OS"
    echo "  -osl -> Launch qemu OS machine."
    echo "  -help -> Show this help."
=======
    echo "./qemu_kvm.sh [options]"
    echo "Options:"
    echo "  -i -> Install the OS via CDROM"
    echo "  -c -> Creates a qcow2 image for OS"
    echo "  -l -> Launch qemu OS machine."
	echo "  -lp -> Launch qemu OS machine with Pinned CPU."
    echo "  -h -> Show this help."
>>>>>>> testes
    echo ""
    exit 0
}

#SWITHC ARGUMENTS
process_args(){
	case "${ARGUMENT1}" in
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

#CHECK IF FILE ALREADY EXISTS
check_file(){
	# Scenario - File exists and is not a directory
	if test -f "$OS_IMG";
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

#CREATE VIRTUAL DISK IMAGE
create_image_os(){
	echo "Creating Virtual Disk...";
	qemu-img create -f qcow2 -o cluster_size=$Cluster_Size,lazy_refcounts=on $OS_IMG $Disk_Size
	exit 1;
}

#LAUNCH QEMU-KVM
os_launch(){
	cd ${IMAGES_DIR}
	echo "Launching OS..."
<<<<<<< HEAD
    echo "$QEMU_ARGS"
	#hexadecimal afinity for cpu placement
    taskset -c $CPU_PINNED \
    qemu-system-x86_64 $QEMU_ARGS
=======
    echo "${QEMU_ARGS[@]}"
    qemu-system-x86_64 ${QEMU_ARGS[@]}
	exit 1;
}

#LAUNCH QEMU-KVM
os_launch_pinned(){
	cd ${IMAGES_DIR}
	echo "Launching OS with pinned CPU: ${CPU_PINNED}..."
    echo "${QEMU_ARGS[@]}"
	#hexadecimal afinity for cpu placement
    taskset -c $CPU_PINNED \
    qemu-system-x86_64 ${QEMU_ARGS[@]}
>>>>>>> testes
	exit 1;
}

#INTALL THE OPERATING SYSTEM N THE VIRTUAL MACHINE
os_install(){
	cd ${IMAGES_DIR}
	echo "Installing OS...";
	taskset -c $CPU_PINNED \
	qemu-system-x86_64 $QEMU_ARGS \
    -cdrom ${OS_ISO}
	exit 1;
}

#--------------------------------------------------------------------
#MAIN
set_variables
process_args
check_file