#!/bin/bash


#####################################################################################################################################
##### GLOBAL VARIABLES #####
#####################################################################################################################################
# Default error handling
#set -euox pipefail

# Defining base PATH
BASE_DIR=$(dirname "${BASH_SOURCE[0]}")
[[ "${BASE_DIR}" == "." ]] && BASE_DIR=$(pwd)

# Defining HugePage default sizes
BIG_PAGES="1048576"
SMALL_PAGES="2048"


# HELP MENU
show_help(){
	echo ""
    echo "${0} [OPTION] [CONFIG FILE PATH]"
    echo "Options:"
    echo "  --setup -----> Set up the environmet optimization"
    echo "  --unsetup ---> Unsets the environment optimization"
    echo "  -h | --help -> Show this help."
    echo ""
    exit 0
}

# SWITHC ARGUMENTS
process_args(){
    for i in "$@"; do
        case "${i}" in
            "")
                echo "No arguments provided,check below. "
                show_help
                shift
                ;;
            --setup=*)
                echo "Setting environment..."
                config_file_path="${i#*=}"
                setup
                shift
                ;;
            "--unsetup")
                echo "Unsetting environment..."
                unsetup
                shift
                ;;
            "-h" | "--help")
                show_help
                shift
                ;;
            *)
                echo "Unrecognised option. -h or --help for help."
                shift
                ;;
        esac
    done
}

#####################################################################################################################################
##### FUNCTIONS #####
#####################################################################################################################################

# Config function to parse arguments
config_fetching(){
    argument_line_nr="$(awk "/${1}/"'{ print NR; exit }' ${config_file_path})" # Stores the Row Nº where the config argument is written
    default_arg="$(head -n ${argument_line_nr} ${config_file_path} | tail -1 | awk "/${1}/"'{print}')" # Stores the old setting of all config arguments
    trimmed=$(echo ${default_arg} | cut -d ':' -f2 | cut -d ',' -f1)
    echo ${trimmed} | cut -d '"' -f2 | cut -d '"' -f2
}

# Huge Pages set-up.
page_size(){
    # Total page calculation
    total_pages=$(( ${VD_RAM} * ${BIG_PAGES} / ${SMALL_PAGES} ))
    # Big pages
    if [ "$(grep Hugepagesize /proc/meminfo | awk '{print $2}')" == "${BIG_PAGES}" ]; then
        hugepages "${BIG_PAGES}" "${VD_RAM}"
        grubsm
    # Small pages
    elif [ "$(grep Hugepagesize /proc/meminfo | awk '{print $2}')" == "${SMALL_PAGES}" ]; then 
        hugepages "${SMALL_PAGES}" "${total_pages}"
        grubsm
    else
        print_error "HP_2 - ${SMALL_PAGES} Not avalilable"
    fi
}

# Allocate Huge Pages size
hugepages(){
    sysctl -w vm.nr_hugepages="${2}"
    # Disable THP 
    echo "never" > "/sys/kernel/mm/transparent_hugepage/enabled"
    echo "never" > "/sys/kernel/mm/transparent_hugepage/defrag"
    
    for i in $(find /sys/devices/system/node/node* -maxdepth 0 -type d); do
        echo "${2}" > "$i/hugepages/hugepages-${1}kB/nr_hugepages"    
    done
}

# Free allocated Huge Pages size
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

# Set Grub File
grubsm(){
    update_grub=$(config_fetching "UPDATE GRUB")

    grub_path="/etc/default/grub"
    grub_cmdline="GRUB_CMDLINE_LINUX"
    grub_tuned_ubuntu22="${grub_cmdline}=\"systemd.unified_cgroup_hierarchy=0\""

    grub_default="${grub_cmdline}_DEFAULT=\"quiet splash\""
    argument_line_nr="$(awk "/${grub_cmdline}/"'{ print NR; exit }' ${grub_path})"
    default_arg="$(head -n ${argument_line_nr} ${grub_path} | tail -1 | awk "/${grub_cmdline}_DEFAULT/"'{print}')"

    # Sets the condition for Ubuntu 22
    grub_default_2="${grub_cmdline}=\"\""
    argument_line_nr2="$(( ${argument_line_nr} + 1 ))"
    default_arg2="$(head -n ${argument_line_nr2} ${grub_path} | tail -1 | awk "/${grub_cmdline}/"'{print}')"

    # Add comment for what ECU config was used and the a timestamp
    argument_line_nr3="$(( ${argument_line_nr} + 2 ))"
    sudo sed -i "${argument_line_nr3}d" ${grub_path}
    sudo sed -i "${argument_line_nr3}i\#${config_file_path}" ${grub_path}

    # Add commented date
    argument_line_nr4="$(( ${argument_line_nr} + 3 ))"
    sudo sed -i "${argument_line_nr4}d" ${grub_path}
    sudo sed -i "${argument_line_nr4}i\#[$(date)]" ${grub_path}

    if [[ ${update_grub} == "yes" ]]; then
        grub_tuned="${grub_cmdline}_DEFAULT=\"quiet splash isolcpus=${vCPU_PINNED} intel_iommu=on preempt=voluntary hugepagesz=1G hugepages=${VD_RAM} default_hugepagesz=1G transparent_hugepage=never\""
        if [[ ${default_arg} == ${grub_tuned} && ${default_arg2} == ${grub_default_2} ]]; then #check if it is already in tunned mode
            echo "Already updated."
        else
            sudo sed -i "s/${default_arg}/${grub_tuned}/" ${grub_path}
            sudo sed -i "s/${default_arg2}/${grub_tuned_ubuntu22}/" ${grub_path}
            sudo update-grub &>/dev/null
        fi
    elif [[ ${update_grub} == "no" ]]; then
        grub_tuned=$(cat ${grub_path} | grep "${grub_cmdline}_DEFAULT=")
        echo "${default_arg}"
        if [[ ${default_arg} == ${grub_default} && ${default_arg2} == ${grub_tuned_ubuntu22} ]]; then # Check if it is already in default mode
            echo "Already default."
        else
            sudo sed -i "s/${grub_tuned}/${grub_default}/" ${grub_path}
            sudo sed -i "s/${grub_tuned_ubuntu22}/${grub_default_2}/" ${grub_path}
            sudo update-grub &>/dev/null
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

    # RAM for VM
    VD_RAM=$(config_fetching "RAM")

    # Boot Logs file
    BOOT_LOGS_PATH="${BASE_DIR}/boot_logs.txt"

    # Isolate vCPU
    vCPU_PINNED=$(cat /sys/devices/system/cpu/cpu*/topology/thread_siblings_list | sort | uniq | tail -1)

	# Set cpu as performance
	for file in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do 
        echo "performance" > $file
    done

	# Sched_rt_runtime_us to 98%
	sysctl kernel.sched_rt_runtime_us=980000 >/dev/null

    # Call grub updater set the HugePages and run qemu with correct parameters
	page_size >/dev/null

    # Creating isolated set to launch qemu
    sudo cset shield --cpu=${vCPU_PINNED} --threads --kthread=on >/dev/null 
    if [[ ${update_grub} == "yes" ]]; then
        echo "GRUB Updated. Reboot to apply all the changes..."
        echo "Use the command below on terminal after you save your work for a fast reboot:"
        echo "      shutdown -r now"
    fi
}

unsetup(){
	# Back to 95% removing cset and freeing HP
	sysctl kernel.sched_rt_runtime_us=950000 >/dev/null
	delete_cset >/dev/null
	free_hugepages "${BIG_PAGES}" "${SMALL_PAGES}" >/dev/null

	# Set cpu to powersave
    for file in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do 
        echo "powersave" > $file
    done

    echo "Note that to unset Grub file insert 'no' in the config file field"
	
    echo "Exit success!"
}

#####################################################################################################################################
##### MAIN #####
#####################################################################################################################################

process_args $@

#####################################################################################################################################
##### COMMAND TO RUN. EXAMPLE #####
#####################################################################################################################################
#sudo ./host_config.sh --setup=/home/franciscosantos/Desktop/git/Tunned_QEMU_VM/config_yes.json