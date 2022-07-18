#!/bin/bash

#####################################################################################################################################
##### GLOBAL VARIABLES #####
#####################################################################################################################################
# Default error handling
set -euo pipefail

# Defining base PATH
BASE_DIR=$(dirname "${BASH_SOURCE[0]}")
[[ "${BASE_DIR}" == "." ]] && BASE_DIR=$(pwd)

# Grub path
GRUB_PATH="/etc/default/grub"

# Defining HugePage default sizes
BIG_PAGES="1048576"
SMALL_PAGES="2048"

#####################################################################################################################################
##### FUNCTIONS #####
#####################################################################################################################################

# HELP MENU
show_help() {
    echo -e "\n${0} [OPTION] [CONFIG FILE PATH]\n"
    echo -e "Note: Run this script using 'sudo'.\n"
    echo "Options:"
    echo -e "\t--setup=* -----> Set up the environmet optimization"
    echo -e "\t--unsetup ---> Unsets the environment optimization"
    echo -e "\t-h | --help -> Show this help.\n"
    exit 0
}

# SWITHC ARGUMENTS
process_args() {
    [ $# == 0 ] && echo "ERROR: No options were provided."

    for i in "$@"; do
        case "${i}" in
            "")
                echo "No arguments provided,check below. "
                show_help
                shift
                ;;
            --setup=*)
                echo "Setting environment..."
                CONFIG_FILE_PATH="${i#*=}"
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

# Config function to parse arguments
config_fetching() {
    ARG_LINE_NR="$(awk "/${1}/"'{ print NR; exit }' ${CONFIG_FILE_PATH})" # Stores the Row Nº where the config argument is written
    OLD_CONFIG="$(head -n ${ARG_LINE_NR} ${CONFIG_FILE_PATH} | tail -1 | awk "/${1}/"'{print}')" # Stores the old setting of all config arguments
    TRIMMED=$(echo ${OLD_CONFIG} | cut -d ':' -f2 | cut -d ',' -f1)
    echo ${TRIMMED} | cut -d '"' -f2 | cut -d '"' -f2
}

# Huge Pages set-up.
page_size() {
    # Total page calculation
    TOTAL_PAGES=$(( ${VD_RAM} * ${BIG_PAGES} / ${SMALL_PAGES} ))
    # Big pages
    if [ "$(grep Hugepagesize /proc/meminfo | awk '{print $2}')" == "${BIG_PAGES}" ]; then
        hugepages "${BIG_PAGES}" "${VD_RAM}"
        grubsm
    # Small pages
    elif [ "$(grep Hugepagesize /proc/meminfo | awk '{print $2}')" == "${SMALL_PAGES}" ]; then 
        hugepages "${SMALL_PAGES}" "${TOTAL_PAGES}"
        grubsm
    else
        echo "HP_2 - ${SMALL_PAGES} Not avalilable"
    fi
}

# Allocate Huge Pages size
hugepages() {
    sysctl -w vm.nr_hugepages="${2}"
    # Disable THP 
    echo "never" > "/sys/kernel/mm/transparent_hugepage/enabled"
    echo "never" > "/sys/kernel/mm/transparent_hugepage/defrag"
    
    for i in $(find /sys/devices/system/node/node* -maxdepth 0 -type d); do
        echo "${2}" > "$i/hugepages/hugepages-${1}kB/nr_hugepages"    
    done
}

# Free allocated Huge Pages size
free_hugepages() {
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
grubsm() {
    GRUB_CMDLINE="GRUB_CMDLINE_LINUX"
    GRUB_UBU22="${GRUB_CMDLINE}=\"systemd.unified_cgroup_hierarchy=0\""

    GRUB_DEFAULT="${GRUB_CMDLINE}_DEFAULT=\"quiet splash\""
    ARG_LINE_NR="$(awk "/${GRUB_CMDLINE}/"'{ print NR; exit }' ${GRUB_PATH})"
    OLD_CONFIG="$(head -n ${ARG_LINE_NR} ${GRUB_PATH} | tail -1 | awk "/${GRUB_CMDLINE}_DEFAULT/"'{print}')"

    # Sets the condition for Ubuntu 22
    GRUB_DEFAULT_2="${GRUB_CMDLINE}=\"\""
    ARG_LINE_NR2="$(( ${ARG_LINE_NR} + 1 ))"
    OLD_CONFIG2="$(head -n ${ARG_LINE_NR2} ${GRUB_PATH} | tail -1 | awk "/${GRUB_CMDLINE}/"'{print}')"

    if [ -z ${CONFIG_FILE_PATH+x} ]; then
        GRUB_TUNED=$(cat ${GRUB_PATH} | grep "${GRUB_CMDLINE}_DEFAULT=")
        if [[ ${OLD_CONFIG} == ${GRUB_DEFAULT} && ${OLD_CONFIG2} == ${GRUB_UBU22} ]]; then
            echo "Already default."
        else
            sudo sed -i "s/${GRUB_TUNED}/${GRUB_DEFAULT}/" ${GRUB_PATH}
            sudo sed -i "s/${GRUB_UBU22}/${GRUB_DEFAULT_2}/" ${GRUB_PATH}
            sudo sed -i "/#DO NOT CHANGE THE TWO LINES BELOW:/d" ${GRUB_PATH}
            sudo sed -i "/#CONFIG_JSON=/d" ${GRUB_PATH}
            sudo sed -i "/#CONFIG_DATE=/d" ${GRUB_PATH}
            sudo update-grub &>/dev/null
        fi
        return
    fi

    UPDATE_GRUB=$(config_fetching "UPDATE GRUB")
    if [[ ${UPDATE_GRUB} == "yes" ]]; then
        GRUB_TUNED="${GRUB_CMDLINE}_DEFAULT=\"quiet splash isolcpus=${VCPU_PINNED} intel_iommu=on preempt=voluntary hugepagesz=1G hugepages=${VD_RAM} default_hugepagesz=1G transparent_hugepage=never\""
        if [[ ${OLD_CONFIG} == ${GRUB_TUNED} && ${OLD_CONFIG2} == ${GRUB_DEFAULT_2} ]]; then
            echo "Already updated."
        else
            sudo sed -i "s/${OLD_CONFIG}/${GRUB_TUNED}/" ${GRUB_PATH}
            sudo sed -i "s/${OLD_CONFIG2}/${GRUB_UBU22}/" ${GRUB_PATH}

            # Add comment to the end of the file for what ECU config was used and the a timestamp
            sudo echo -e "\n\n#DO NOT CHANGE THE TWO LINES BELOW:" >> ${GRUB_PATH}
            sudo echo "#CONFIG_JSON=${CONFIG_FILE_PATH}" >> ${GRUB_PATH}
            sudo echo "#CONFIG_DATE=$(date)" >> ${GRUB_PATH}

            sudo update-grub &>/dev/null
        fi
    fi
}

# Delete cset prevously created
delete_cset() {
    sudo cset set -d system
    while [[ $(sudo cset set -d system) =~ "done" ]]; do 
        sudo cset set -d system
    done
    sudo cset set -d user
}

# LAUNCHER for VM
setup() {
    # RAM for VM
    VD_RAM=$(config_fetching "RAM")

    # Isolate vCPU
    VCPU_PINNED=$(cat /sys/devices/system/cpu/cpu*/topology/thread_siblings_list | sort | uniq | tail -1)

	# Set cpu as performance
	for file in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do 
        echo "performance" > $file
    done

	# Sched_rt_runtime_us to 98%
	sysctl kernel.sched_rt_runtime_us=980000 >/dev/null

    # Call grub updater set the HugePages and run qemu with correct parameters
	page_size >/dev/null

    if [[ ${UPDATE_GRUB} == "yes" ]]; then
        echo "GRUB Updated. Reboot to apply all the changes..."
        echo "Use the command below on terminal after you save your work for a fast reboot:"
        echo "      shutdown -r now"
    fi
}

unsetup() {
    grubsm
	# Back to 95% removing cset and freeing HP
	sysctl kernel.sched_rt_runtime_us=950000 >/dev/null
	delete_cset >/dev/null
	free_hugepages "${BIG_PAGES}" "${SMALL_PAGES}" >/dev/null

	# Set cpu to powersave
    for file in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do 
        echo "powersave" > $file
    done

    echo "Note that to unset Grub file insert 'no' in the config file field"
    
}

#####################################################################################################################################
##### MAIN #####
#####################################################################################################################################

process_args $@

#####################################################################################################################################
##### COMMAND TO RUN. EXAMPLE #####
#####################################################################################################################################
#sudo ./host_config.sh --setup=/home/franciscosantos/Desktop/git/Tunned_QEMU_VM/config_yes.json