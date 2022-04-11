#!/bin/bash

#Check cpu L3 cache number
#it is missing comparing the first with the others and so on logic half an array
#verificar o grupo com menos cpus e talvez usar o ultimo
#pedir ao valtaer pra corre ro lscpu -e no servidor
#array=((0,1,2),(3,4,5))
array=()

cpu=-1
while IFS= read -r line
do
    (( ${cpu} < 0 )) && ((cpu++)) && continue

    #Grab L3 value
    cache_column=$(echo $line | awk '{print $5}')
    arr=($(echo ${cache_column} | tr ":" "\n"))

    array[${cpu}]=${arr[3]}

    ((cpu++))
    #To grab the output of the lscpu command
done <<< $(lscpu -e)
echo "OK. All L3 caches are equal."
echo "${array[@]}"