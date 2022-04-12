
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

    # Name
    OPTS="$OPTS -name ${ARGUMENT2}"

    # Processor
    CORES="4"
	THREADS="2"
    OPTS="$OPTS -cpu max,hv_relaxed,hv_spinlocks=0x1fff,hv_vapic,hv_time"
    #OPTS="$OPTS -smp cores=${CORES},threads=${THREADS}"
    OPTS="$OPTS -enable-kvm"

    # Machine
    #see what is type q35
    OPTS="$OPTS -machine accel=kvm"

    # Hardware clock
	OPTS="$OPTS -rtc base=localtime,clock=host"
    
	# IMAGE
	Disk_Size="40G"
	Cluster_Size="64K"
	L2_Cache_Size="5M"
    #1Mb for 8Gb using 64Kb
    #CACHE CLEAN IN SECONDS
	Cache_Clean_Interval="60"
    OPTS="$OPTS -drive file=${OS_IMG},l2-cache-size=${L2_Cache_Size},cache=writethrough,cache-clean-interval=${Cache_Clean_Interval}"
    
    # RAM
    VD_RAM="8G"  
	OPTS="$OPTS -m ${VD_RAM}"
}

#HELP MENU
show_help(){
	echo ""
    echo "./create_system.sh [options]"
    echo "Options:"
    echo "  -osi -> Install the OS via CDROM"
    echo "  -osc -> Creates a qcow2 image for OS"
    echo "  -osl -> Launch qemu OS machine."
    echo "  -help -> Show this help."
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
		show_help
		shift
		;;
	*)
		echo "Unrecognised option"
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
	echo "Launching OS...";
	#hexadecimal afinity for cpu placement
	taskset 0x80 \
    qemu-system-x86_64 $OPTS
	#sem o smp faz 1 proc 1 core
	#com smp faz 4 cores e 8 threads...
	# \
	# we see it in lstopo --of console --no-io --no-caches
	#we pin core 0 
	#-vga virtio -display gtk,gl=on\
	exit 1;
}

#INTALL THE OPERATING SYSTEM N THE VIRTUAL MACHINE
os_install(){
	cd ${IMAGES_DIR}
	echo "Installing OS...";
	qemu-system-x86_64 $OPTS \
    -cdrom ${OS_ISO}
	exit 1;
}

#--------------------------------------------------------------------
#MAIN
set_variables
process_args
check_file







# Turn off QEMU-window video
#OPTS="$OPTS -vga none"

# Graphic card passthrough (AMD Radeon R9 280x)
#OPTS="$OPTS -device vfio-pci,host=01:00.0,multifunction=on"
#OPTS="$OPTS -device vfio-pci,host=01:00.1"

# System drive
#OPTS="$OPTS -drive id=disk0,if=none,cache=none,format=raw,file=/mnt/ssd-linux/winvm/img"
#OPTS="$OPTS -device driver=virtio-scsi-pci,id=scsi0"
#OPTS="$OPTS -device scsi-hd,drive=disk0"
