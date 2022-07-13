#!/bin/bash

#####################################################################################################################################
##### FUNCTIONS #####
#####################################################################################################################################
config_file_path=${2:-config.json}

# Config function to parse arguments
config_fetching(){
    # Config file path
    file_config="${config_file_path}"
    
    argument_line_nr="$(awk "/${1}/"'{ print NR; exit }' ${file_config})" # Stores the Row Nº where the config argument is written
    default_arg="$(head -n ${argument_line_nr} ${file_config} | tail -1 | awk "/${1}/"'{print}')" # Stores the old setting of all config arguments
    trimmed=$(echo ${default_arg} | cut -d ':' -f2 | cut -d ',' -f1)
    echo ${trimmed} | cut -d '"' -f2 | cut -d '"' -f2
}

# GLOBAL VARIABLES
# Defining base PATH
BASE_DIR=$(dirname "${BASH_SOURCE[0]}")
[[ "${BASE_DIR}" == "." ]] && BASE_DIR=$(pwd)

# Arguments fishing from config file:

# RAM for VM
VD_RAM=$(config_fetching "RAM")

# Defining HugePage default sizes
big_pages="1048576"
small_pages="2048"
# Boot Logs file
boot_logs_path="${BASE_DIR}/boot_logs.txt"

# Pinned vCPU
vCPU_PINNED=$(cat /sys/devices/system/cpu/cpu*/topology/thread_siblings_list | sort | uniq | tail -1)

# Huge Pages set-up.
page_size(){
    # Total page calculation
    total_pages=$(( ${VD_RAM} * ${big_pages} / ${small_pages} ))
    # Big pages
    if [ "$(grep Hugepagesize /proc/meminfo | awk '{print $2}')" == "${big_pages}" ]; then
        hugepages "${big_pages}" "${VD_RAM}"
        grubsm
    # Small pages
    elif [ "$(grep Hugepagesize /proc/meminfo | awk '{print $2}')" == "${small_pages}" ]; then 
        hugepages "${small_pages}" "${total_pages}"
        grubsm
    else
        print_error "HP_2 - ${small_pages} Not avalilable"
    fi
}

# Allocate huge pages size
hugepages(){
    sysctl -w vm.nr_hugepages="${2}"
    # Disable THP 
    echo "never" > "/sys/kernel/mm/transparent_hugepage/enabled"
    echo "never" > "/sys/kernel/mm/transparent_hugepage/defrag"
    
    for i in $(find /sys/devices/system/node/node* -maxdepth 0 -type d); do
        echo "${2}" > "$i/hugepages/hugepages-${1}kB/nr_hugepages"    
    done
}

# Free allocated huge pages size
free_hugepages(){
    sysctl -w vm.nr_hugepages="0"
    # Enable THP
    echo "always" > "/sys/kernel/mm/transparent_hugepage/enabled"
    echo "always" > "/sys/kernel/mm/transparent_hugepage/defrag"

    for i in $(find /sys/devices/system/node/node* -maxdepth 0 -type d); do
        echo 0 > "$i/hugepages/hugepages-${1}kB/nr_hugepages"
        echo 0 > "$i/hugepages/hugepages-${2}kB/nr_hugepages" 
    done
}

# Set Grub File to Static Method:
grubsm(){
    
    # If cset gives you mount error is because newer version of Linux:
    # Just add this to the grub file: 
    #meter um comment com o path para  latest config
    update_grub=$(config_fetching "Update Grub")
    
    grub_path="/etc/default/grub"
    base=(
        "GRUB_CMDLINE_LINUX"
        )
    base+=(
        "_DEFAULT"
        )
    echo ${base}

    grub_default="GRUB_CMDLINE_LINUX_DEFAULT=\"quiet splash\""
    grub_default_2="GRUB_CMDLINE_LINUX=\"\""

    argument_line_nr="$(awk "/GRUB_CMDLINE_LINUX_DEFAULT/"'{ print NR; exit }' ${grub_path})"
    default_arg="$(head -n ${argument_line_nr} ${grub_path} | tail -1 | awk "/GRUB_CMDLINE_LINUX_DEFAULT/"'{print}')"

    if [[ ${update_grub} == "yes" ]]; then
        grub_tuned="GRUB_CMDLINE_LINUX_DEFAULT=\"quiet splash isolcpus=${vCPU_PINNED} intel_iommu=on preempt=voluntary hugepagesz=1G hugepages=${VD_RAM} default_hugepagesz=1G transparent_hugepage=never\""
        grub_tuned_ubuntu22="GRUB_CMDLINE_LINUX=\"systemd.unified_cgroup_hierarchy=0\""
        if [[ ${default_arg} == ${grub_tuned} ]]; then #check if it is already in tunned mode
            echo "Already updated."
        else
            sudo sed -i "s/${default_arg}/${grub_tuned}/" ${grub_path}
            sudo update-grub
        fi
    elif [[ ${update_grub} == "no" ]]; then
        grub_tuned=$(cat ${grub_path} | grep "GRUB_CMDLINE_LINUX_DEFAULT=")
        if [[ ${default_arg} == ${grub_default} ]]; then # Check if it is already in default mode
            echo "Already default."
        else
            sudo sed -i "s/${grub_tuned}/${grub_default}/" ${grub_path}
            sudo update-grub
        fi
    fi
}

# Delete cset prevously created
delete_cset(){
    sudo cset set -d system
    while [[ $(sudo cset set -d system) =~ "done" ]]; do 
        sudo cset set -d system
    done
    sudo cset set -d user
}

# LAUNCHER for VM
setup(){
	# Set cpu as performance
	for file in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do 
        echo "performance" > $file
    done

	# Sched_rt_runtime_us to 98%
	sysctl kernel.sched_rt_runtime_us=980000 >/dev/null

    # Call grub updater set the HugePages and run qemu with correct parameters
	page_size #>/dev/null

    # Creating isolated set to launch qemu
    sudo cset shield --cpu=${vCPU_PINNED} --threads --kthread=on >/dev/null 

    echo "Reboot to apply all the changes..."
}

unsetup(){
	# Back to 95% removing cset and freeing HP
	sysctl kernel.sched_rt_runtime_us=950000 >/dev/null
	delete_cset >/dev/null
	free_hugepages "${big_pages}" "${small_pages}" >/dev/null

	# Set cpu to powersave
    for file in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do 
        echo "powersave" > $file
    done

	# Remove boot file
	sudo rm -f ${boot_logs_path}
    echo "Exit success!"
}

#####################################################################################################################################
##### MAIN #####
#####################################################################################################################################


if [[ ${1} == "--setup" ]]; then
    echo "Setting environment..."
    setup
elif [[ ${1} == "--unsetup" ]]; then
    echo "Unsetting environment..."
    unsetup
else
    echo "Error: Missing argument (--setup or --unsetup)."
fi


