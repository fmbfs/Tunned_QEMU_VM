#!/bin/bash

#yes no confirmation
yay_nay(){
	while true; 
		do
			read -p "Do you want to create/overwrite it? [y/n] " yn
			case $yn in
				[Yy]* ) mkdir "${1}"; echo "${1} created!"; break;;
				[Nn]* ) break;;
				* ) echo "Please answer yes or no.";;
			esac
		done	
}

#check if the directory structure is as required
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

# CHECK HARDISK IMAGE
check_file(){
	# Scenario - File exists and is not a directory
	if test -f "${1}";
	then
		echo "${1} hardisk image exists!"
		yay_nay ${1}
	else
		echo "${1} hardisk image created!"
	fi
}
