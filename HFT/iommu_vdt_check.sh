#!/bin/bash

#Check if IOMMU and VT-D are enabled or not
echo "Check IOMMU and VT-D enabled..."
if compgen -G "/sys/kernel/iommu_groups/*/devices/*" > /dev/null; then
    echo "AMD's IOMMU / Intel's VT-D is enabled in the BIOS/UEFI."
else
    echo "AMD's IOMMU / Intel's VT-D is not enabled in the BIOS/UEFI"
    exit 0
fi
