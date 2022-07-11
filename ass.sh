# Config file
file_config="./config.json"

# Config function to parse arguments
config_fishing(){
    argument_line_nr="$(awk "/${1}/"'{ print NR; exit }' ${file_config})" # Stores the Row Nº where the config argument is written
    default_arg="$(head -n ${argument_line_nr} ${file_config} | tail -1 | awk "/${1}/"'{print}')" # Stores the old setting of all config arguments
    trimmed=$(echo ${default_arg} | cut -d ':' -f2 | cut -d ',' -f2)
    echo ${trimmed} | cut -d '"' -f2 | cut -d '"' -f2
}

grubsm(){
    update_grub=$(config_fishing "Update Grub")
    echo "${update_grub}"
    grub_path="/etc/default/grub"
    grub_default="GRUB_CMDLINE_LINUX_DEFAULT=\"quiet splash\""
    
    argument_line_nr="$(awk "/GRUB_CMDLINE_LINUX_DEFAULT/"'{ print NR; exit }' ${grub_path})"
    default_arg="$(head -n ${argument_line_nr} ${grub_path} | tail -1 | awk "/GRUB_CMDLINE_LINUX_DEFAULT/"'{print}')"

    if [[ ${update_grub} == "yes" ]]; then
        grub_tuned="GRUB_CMDLINE_LINUX_DEFAULT=\"quiet splash isolcpus=${vCPU_PINNED} intel_iommu=on preempt=voluntary hugepagesz=1G hugepages=${VD_RAM} default_hugepagesz=1G transparent_hugepage=never\""
        if [[ ${default_arg} == ${grub_tuned} ]]; then #check if it is already in tunned mode
            echo "already updated"
        else
            sudo sed -i "s/${grub_default}/${grub_tuned}/" ${grub_path}
            # sudo update-grub && shutdown -r now
        fi
    elif [[ ${update_grub} == "no" ]]; then
        grub_tuned=$(cat ${grub_path} | grep "GRUB_CMDLINE_LINUX_DEFAULT=")
        if [[ ${default_arg} == ${grub_default} ]]; then # Check if it is already in default mode
            echo "already default"
        else
            sudo sed -i "s/${grub_tuned}/${grub_default}/" ${grub_path}
            # sudo update-grub && shutdown -r now
        fi
    fi
    
}

grubsm