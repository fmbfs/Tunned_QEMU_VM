#!/bin/bash

#------------------------------------------------------------------
# FUNTIONS
#trap for debug
trap(){
	echo "trap trap trap!!!!!!"
}

#print_error -- Error handler function
print_error(){
    echo "Error: $1"; exit 1
}

# iommu_on -- Confirm that IOMMU is on and able
iommu_on()
{
    if [[  "$(2> /dev/null dmesg)" =~ "DMAR: IOMMU enabled" ]]; then
        #echo "iommu_on"
        :
    else 
        print_error "HC_1 Not OK --> reboot host to fix."
    fi
}

iommu_group(){
    shopt -s nullglob
    for g in /sys/kernel/iommu_groups/*; do
        echo "IOMMU Group ${g##*/}:"
        for d in $g/devices/*; do
            echo -e "\t$(lspci -nns ${d##*/})"
        done;
    done;
}


# iommu_vdt_check -- Check if IOMMU and VT-D are enabled or not
iommu_vdt_check()
{
    if compgen -G "/sys/kernel/iommu_groups/*/devices/*" > /dev/null; then
        #echo "iommu_vdt"
        :
    else
        print_error "HC_2 Not OK"
    fi
}

# Check vCPU L3 cache number and groups the last threads
grouping()
{
    i=-4
    while IFS= read -r line
    do
        if (( ${i} < 0 )); then
            i=$((${i}+1)) && continue
        fi

        #Grab CPU, CORE and L3 value
        arr=($(echo $line  | tr "," "\n"))
        cpu_arr[${i}]=${arr[0]}
        core_arr[${i}]=${arr[1]}
        l3_arr[${i}]=${arr[7]}  

        i=$((${i}+1))
    done <<< $(lscpu -p)

    #echo "vCPUS total..."
    #echo "${i}"

    #echo "l3     --> ${l3_arr[@]}"
    dif_l3=($(echo ${l3_arr[@]} ${l3_arr[@]} | tr ' ' '\n' | sort | uniq -d))
    #echo "different l3 --> ${dif_l3[@]}"

    #grab thrad number
    thread=($(lscpu | grep Thread | awk '{print $4}'))
    #echo "thread --> $thread"

    j=0
    if [ "${#dif_l3[@]}" == 1 ]; then
        #echo "cores  --> ${core_arr[@]}"
        dif_cores=($(echo ${core_arr[@]} ${core_arr[@]} | tr ' ' '\n' | sort | uniq -d))
        #echo "different cores --> ${dif_cores[@]}"
        size=${#dif_cores[@]}

        #echo "cpu    --> ${cpu_arr[@]}"
        dif_cpu=($(echo ${cpu_arr[@]} ${cpu_arr[@]} | tr ' ' '\n' | sort | uniq -d))
        #echo "different cpu --> ${dif_cpu[@]}"
        while [[ ${j} < $((${thread}-1)) ]] 
        do
            group[${j}]=${cpu_arr[$((${size}-1))]}
            j=$((${j}+1))
            group[${j}]=${cpu_arr[-1]}
        done
    else
        print_error "HC_3 Not OK --> L3 cache not the same. Check with lscpu -e"
    fi
    #echo "group: ${group[@]}"
}

#check siblings test if it group by l3 cache
#cat /sys/devices/system/cpu/cpu*/topology/thread_siblings_list | sort | uniq

#------------------------------------------------------------------
# MAIN

#iommu_on
#echo " ajjsajas"
#iommu_vdt_check
#iommu_group | grep -i --color '2D\|3D\|VGA'
grouping