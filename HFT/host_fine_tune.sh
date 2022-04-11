#!/bin/bash

#This part runs before the flutter app
#to check if the host has everything
#able to run the tunned

#default error handeling
#ver se acrescent x a frente do o
set -euo pipefail

#trap cmd_exit EXIT

#cmd_exit()
##{
#    echo "qjajadhkjs"
#}

print_error()
{
    echo "Error: $1"; exit 1
}

#Check if IOMMU and VT-D are enabled or not
echo "Check IOMMU and VT-D enabled..."
if compgen -G "/sys/kernel/iommu_groups/*/devices/*" > /dev/null; then
    echo "AMD's IOMMU / Intel's VT-D is enabled in the BIOS/UEFI."
else
    echo "AMD's IOMMU / Intel's VT-D is not enabled in the BIOS/UEFI"
    exit 0
fi

echo " "
#Ensuring that the groups are valid
ignorar()
{
    echo "Ensuring valid groups..."
    shopt -s nullglob
    for g in $(find /sys/kernel/iommu_groups/* -maxdepth 0 -type d | sort -V); do
        echo "IOMMU Group ${g##*/}:"
        for d in $g/devices/*; do
            echo -e "\t$(lspci -nns ${d##*/})"
        done
    done
}
echo " "
#Confirm that IOMMU is on and able
echo "Confirm Input-Output Memory Management Unit (IOMMU)..."
#dmesg | grep -i -e DMAR -e IOMMU
if [[  "$(2> /dev/null dmesg)" =~ "DMAR: IOMMU enabled" ]]; then
    echo "OK"
else 
    print_error "Not OK"
fi

#To link other files
#./ to run independent if needed
./teste.sh

   
    
