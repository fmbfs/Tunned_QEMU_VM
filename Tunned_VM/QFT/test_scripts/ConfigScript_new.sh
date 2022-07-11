#!/bin/bash

#####################################################################################################################################
##### DEFAULTS #####
#####################################################################################################################################

file_config="./config.json"

# HELP MENU
show_help(){
	echo ""
    echo "${0} [OPTION]"
    echo "Options:"
    echo "  -vlab -----> Config Options for Vlab"
    echo "  -h -----> Show this help."
    echo ""
    exit 0
}

# SWITCH ARGUMENTS
process_args(){
	case "${1:--vlab}" in
	"")
		echo "No arguments provided,check below. "
		show_help
		shift
		;;
	"-vlab")
        vlab_configs
        echo "Config Options for Vlab..."
		shift
		;;
	"-h")
		show_help
		shift
		;;
	*)
		echo "Unrecognised option. -h for help."
		shift
		;;
	esac	
}

#validade the cluster sizes range

# Default
vlab_configs(){
    config_args_list=("Name" "RAM" "VSD" "VSD Cluster" "Cache Clean" "Update Grub")
    new_config_values=("test" "20" "10" "64" "30" "no") # Change here for new configs

    while [[ ${i:-0} != ${#config_args_list[@]} ]]
    do 
        argument_line_nr="$(awk "/${config_args_list[i]}/"'{ print NR; exit }' ${file_config})" # Stores the Row Nº where the config argument is written
        default_arg[i]="$(head -n ${argument_line_nr} ${file_config} | tail -1)" # Stores the old setting of all config arguments
    
        new_arg="        \"${config_args_list[i]}\":\"${new_config_values[i]}\","
        sed -i "${argument_line_nr}s/${default_arg[i]}/${new_arg}/" ${file_config}

        ((i++))
    done

    #set values to default...see if it is needed
}

#####################################################################################################################################
##### MAIN #####
#####################################################################################################################################

main(){
    process_args
    vlab_configs
}

#####################################################################################################################################
##### RUN #####
#####################################################################################################################################

main
