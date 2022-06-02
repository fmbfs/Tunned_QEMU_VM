#!/bin/bash

#------------------------------------------------------------------
#FUNCTIONS
# Yes no confirmation
yay_nay(){
	while true; 
		do
			read -p "Do you want to create/overwrite it? [y/n] " yn
			case $yn in
				[Yy]* ) mkdir "${1}"; echo "${1} created!"; exit 0;;
				[Nn]* ) exit 0;;
				* ) echo "Please answer yes or no.";;
			esac
		done	
}

# Check if the directory structure is as required
check_dir(){
	if [ -d "${1}" ];
	then
		#echo "OS iso: ${1} directory exists!"
		:
	else
		echo "${1} directory does not exist."
		yay_nay ${1}
	fi
}

# Check hard disk image
check_file(){
	# Scenario - File exists and is not a directory
	if test -f "${1}";
	then
		echo "${1} virtual hardisk image exists!"
		yay_nay ${1}

	else
		echo "${1} virtual hardisk image created!"
	fi
}

#------------------------------------------------------------------
#MAIN
