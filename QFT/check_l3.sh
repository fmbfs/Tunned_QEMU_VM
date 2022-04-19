#!/bin/bash
#------------------------------------------------------------------
#MACROS

#------------------------------------------------------------------
#FUNCTIONS
#print_error -- Error handler function
print_error()
{
    echo "Error: $1"; exit 1
} #print_error  end


#Check vCPU L3 cache number and groups the last threads
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

    echo "Mapping..."
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
        echo "L3 cache not equal..."
        print_error
    fi
    echo "grupos ${group[@]}"
}




#--------------------------------------------------------------------
# MAIN
grouping