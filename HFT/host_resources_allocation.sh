#!/bin/bash
#------------------------------------------------------------------
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
    echo "Confirm Input-Output Memory Management Unit (IOMMU)..."
    #dmesg | grep -i -e DMAR -e IOMMU
    if [[  "$(2> /dev/null dmesg)" =~ "DMAR: IOMMU enabled" ]]; then
        echo "OK"
    else 
        print_error "Not OK"
    fi
} #iommu_on end

#iommu_vdt_check -- Check if IOMMU and VT-D are enabled or not
iommu_vdt_check()
{
    echo "Check IOMMU and VT-D enabled..."
    if compgen -G "/sys/kernel/iommu_groups/*/devices/*" > /dev/null; then
        echo "AMD's IOMMU / Intel's VT-D is enabled in the BIOS/UEFI."
    else
        echo "AMD's IOMMU / Intel's VT-D is not enabled in the BIOS/UEFI"
        exit 0
    fi
} #iommu_vdt_check end

#l3_cache_number -- Check cpu L3 cache number
#it is missing comparing the first with the others 
#and so on logic half an array verificar o grupo 
#com menos cpus e talvez usar o ultimo
#pedir ao valtaer pra corre ro lscpu -e no servidor
#array=((0,1,2),(3,4,5))
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

    echo "OK. All L3 caches are equal."
    echo "${arr_l3[@]}"
    #usar lscpu -p talvez seja mais rapido pois sai parcelado o output
    #Note the server has more than one L3 group!
    #Since all cores are connected to the same L3 in this example, 
    #it does not matter much how many CPUs you pin and isolate as 
    #long as you do it in the proper thread pairs. For instance, 
    #(0 e o 6), (1 e o 7), etc. 

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
#iommu_on
#iommu_vdt_check
l3_cache_number
cores_check
#valid_groups