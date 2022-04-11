#!/bin/bash

#Confirm that IOMMU is on and able
echo "Confirm Input-Output Memory Management Unit (IOMMU)..."
#dmesg | grep -i -e DMAR -e IOMMU
if [[  "$(2> /dev/null dmesg)" =~ "DMAR: IOMMU enabled" ]]; then
    echo "OK"
else 
    print_error "Not OK"
fi