
#
#
#
##################################################
#		Improvments to be done:
#		
#		
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

	#RAM
	VD_RAM="4G"
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
	qemu-img create -f qcow2 $OS_IMG $Disk_Size
	exit 0;
}

#LAUNCH QEMU-KVM
os_launch(){
	cd ${IMAGES_DIR}
	echo "Launching OS basic commands...";
	qemu-system-x86_64 -cpu host --enable-kvm -smp 2\
	-name "${ARGUMENT2}"\
	-rtc base=localtime,clock=host\
	-drive file=${OS_IMG} -m ${VD_RAM}
	
	exit 0;
}

#--------------------------------------------------------------------
#MAIN
set_variables
process_args
check_file