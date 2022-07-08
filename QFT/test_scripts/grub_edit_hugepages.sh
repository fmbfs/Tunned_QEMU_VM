#!/bin/bash

#------------------------------------------------------------------
#FUNCTIONS

# Set Grub File to Static Method:
grubsm(){
    grub_path="/etc/default/grub"
    grub_default="GRUB_CMDLINE_LINUX_DEFAULT=\"quiet splash\""
    if [[ ${1} == "tuned" ]]; then
        if [[ ${2} =~ "isolcpus" ]]; then
            vCPU_PINNED=$(cat /sys/devices/system/cpu/cpu*/topology/thread_siblings_list | sort | uniq | tail -1)
            grub_isol="isolcpus=${vCPU_PINNED}"
        else
            grub_isol=""
        fi
        grub_tuned="GRUB_CMDLINE_LINUX_DEFAULT=\"quiet splash ${grub_isol} intel_iommu=on preempt=voluntary hugepagesz=1G hugepages=${VD_RAM} default_hugepagesz=1G transparent_hugepage=never\""
        sudo sed -i "s/${grub_default}/${grub_tuned}/" ${grub_path}
    else
        grub_tuned=$(cat ${grub_path} | grep "GRUB_CMDLINE_LINUX_DEFAULT=")
        sudo sed -i "s/${grub_tuned}/${grub_default}/" ${grub_path}
    fi
    sudo update-grub
}

#------------------------------------------------------------------
# MAIN
grubsm tuned isolcpus