#!/bin/sh

if [ $# -ne 1 ]; then
  echo "$0 <kernel-flavor>"
  exit 1
fi

flavor=$1

version=$(grep ^Version: nvidia-open-driver-G06.spec |awk '{print $2}')

for id in $(cat pci_ids-$version | cut -d " " -f 1|sed 's/0x//g'); do
        echo "Supplements:    modalias(kernel-$flavor:pci:v000010DEd0000${id}sv*sd*bc03sc0[02]i00*)"
done

exit 0

