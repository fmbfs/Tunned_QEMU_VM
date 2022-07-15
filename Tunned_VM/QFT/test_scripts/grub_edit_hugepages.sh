#!/bin/bash

#------------------------------------------------------------------
#FUNCTIONS

# Set Grub File to Static Method:
grubsm(){
    GRUB_PATH="/etc/default/grub"
    GRUB_DEFAULT="GRUB_CMDLINE_LINUX_DEFAULT=\"quiet splash\""
    if [[ ${1} == "tuned" ]]; then
        if [[ ${2} =~ "isolcpus" ]]; then
            VCPU_PINNED=$(cat /sys/devices/system/cpu/cpu*/topology/thread_siblings_list | sort | uniq | tail -1)
            grub_isol="isolcpus=${VCPU_PINNED}"
        else
            grub_isol=""
        fi
        GRUB_TUNED="GRUB_CMDLINE_LINUX_DEFAULT=\"quiet splash ${grub_isol} intel_iommu=on preempt=voluntary hugepagesz=1G hugepages=${VD_RAM} default_hugepagesz=1G transparent_hugepage=never\""
        sudo sed -i "s/${GRUB_DEFAULT}/${GRUB_TUNED}/" ${GRUB_PATH}
    else
        GRUB_TUNED=$(cat ${GRUB_PATH} | grep "GRUB_CMDLINE_LINUX_DEFAULT=")
        sudo sed -i "s/${GRUB_TUNED}/${GRUB_DEFAULT}/" ${GRUB_PATH}
    fi
    sudo update-grub
}

#------------------------------------------------------------------
# MAIN
grubsm tuned isolcpus