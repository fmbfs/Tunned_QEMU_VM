#!/bin/bash

#Defaults 
#default error handeling
set -euo pipefail
#set -euox pipefail

#------------------------------------------------------------------
#FUNCTIONS
#print_error -- Error handler function
print_error()
{
    echo "Error: $1"; exit 1
} #print_error  end

#iommu_on -- Confirm that IOMMU is on and able
iommu_on()
{
    if [[  "$(2> /dev/null dmesg)" =~ "DMAR: IOMMU enabled" ]]; then
        :
    else 
        print_error "Not OK"
    fi
} #iommu_on end

#iommu_vdt_check -- Check if IOMMU and VT-D are enabled or not
iommu_vdt_check()
{
    if compgen -G "/sys/kernel/iommu_groups/*/devices/*" > /dev/null; then
        :
    else
        print_error "Not OK"
    fi
} #iommu_vdt_check end

#l3_cache_number -- Check vCPU L3 cache number
l3_cache_number()
{
    arr_l3=()
    cpu=-1
    while IFS= read -r line
    do
        if (( ${cpu} < 0 )); then
            cpu=$((${cpu}+1)) && continue
        fi

        #Grab L3 value
        cache_column=$(echo $line | awk '{print $5}')
        arr=($(echo ${cache_column} | tr ":" "\n"))
        
        arr_l3[${cpu}]=${arr[3]}

        cpu=$((${cpu}+1))
        #To grab the output of the lscpu command
    done <<< $(lscpu -e)
    echo "vCPUS..."
    echo "${arr_l3[@]}"
    #this is not usefull at the moment

} #l3_cache_number end

#cores_check -- check the group of cores
cores_check()
{
    arr_cores=()
    cores=-1
    while IFS= read -r line
    do
        if (( ${cores} < 0 )); then
            cores=$((${cores}+1)) && continue
        fi
     
        #Grab cores value
        cache_column=$(echo $line | awk '{print $4}')
        arr1=($(echo ${cache_column}))

        arr_cores[${cores}]=${arr1[0]}
        cores=$((${cores}+1))
        #To grab the output of the lscpu command
    done <<< $(lscpu -e)
    echo "Cores..."
    echo "${arr_cores[@]}"

     #this is not usefull at the moment

} #cores_check end

#valid_groups -- Ensuring that the groups are valid
valid_groups()
{
    echo "Ensuring valid groups..."
    shopt -s nullglob
    for g in $(find /sys/kernel/iommu_groups/* -maxdepth 0 -type d | sort -V); do
        echo "IOMMU Group ${g##*/}:"
        for d in $g/devices/*; do
            echo -e "\t$(lspci -nns ${d##*/})"
        done
    done
} #valid_groups end

#------------------------------------------------------------------
#MAIN
iommu_on
iommu_vdt_check
#l3_cache_number
#cores_check
#valid_groups