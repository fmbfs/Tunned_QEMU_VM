
#
#
#
#################################################
#		Improvments to be done:
#		- none at the moment 28-03-2022
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

	#OS --> Windows 10
	OS_ISO="${IMAGES_DIR}/Win10_21H2_English_x64.iso"
	VD_NAME="${ARGUMENT2}.qcow2"
	OS_IMG="${QEMU_VD}/${VD_NAME}"

	#QEMU
	Disk_Size="40G"
	Cluster_Size="64K"
	L2_Cache_Size="5M"
	#1Mb for 8Gb using 64Kb
	#RAM
	VD_RAM="4G"

	#CACHE CLEAN IN SECONDS
	Cache_Clean_Interval="60"

	#CPU Tunning
	CORES="2"
	THREADS="4"
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
	qemu-img create -f qcow2 -o cluster_size=$Cluster_Size $OS_IMG $Disk_Size
	exit 0;
}

#LAUNCH QEMU-KVM
os_launch(){
	cd ${IMAGES_DIR}
	echo "Launching OS...";
	qemu-system-x86_64 -cpu max --enable-kvm -smp cores=${CORES},threads=${THREADS}\
	-name 'dummy'\
	-rtc base=localtime,clock=host\
	-drive file=${OS_IMG},l2-cache-size=${L2_Cache_Size},cache=writethrough,cache-clean-interval=${Cache_Clean_Interval} -m ${VD_RAM}
	
	#-vga virtio -display gtk,gl=on\
	#-usb -device usb-tablet -netdev user,id=mynet1 -device virtio-net,netdev=mynet1,mac=02:ca:fe:f0:0d:02\
	exit 0;
}

#INTALL THE OPERATING SYSTEM N THE VIRTUAL MACHINE
os_install(){
	cd ${IMAGES_DIR}
	echo "Installing OS...";
	qemu-system-x86_64 -cpu max --enable-kvm -smp cores=${CORES},threads=${THREADS}\
	-cdrom ${OS_ISO}\
	-name 'dummy'\
	-rtc base=localtime,clock=host\
	-drive file=${OS_IMG},l2-cache-size=${L2_Cache_Size},cache=writethrough,cache-clean-interval=${Cache_Clean_Interval} -m ${VD_RAM}
	exit 0;
}

#--------------------------------------------------------------------
#MAIN
set_variables
process_args
check_file