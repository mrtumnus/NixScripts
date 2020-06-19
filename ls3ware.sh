#!/bin/bash

# Collect information from 3ware RAID controller in order to correlate
# drive model/serial with physical location and logical path. This
# information is compiled within a single-dimensional array, with
# disk descriptors stored sequentially.
# Each disk descriptor will have the following form:
#  [0] = pX             Physical Slot identifier (3ware)
#  [1] = uY             Unit identifier (3ware)
#  [2] = N.NN           Size in TB
#  [3] = ABCDEF         Model Number
#  [4] = ABCDEF         Serial Number
#  [5] = /dev/sdZ       Device Path

ix=0
num=0

# Start off with info from RAID controller
# Output has the form:
# p1 OK u1 2.73 TB SATA 1 - WDC WD30EZRX-00D8PB0
while read line; do
  if [[ ${line} =~ p[[:digit:]] ]]; then
    if [[ ${line} =~ (p[[:digit:]]).*(u[[:digit:]])[[:space:]]+([[:digit:]]\.[[:digit:]]+)[[:space:]]TB.*\-[[:space:]]+(.*) ]]; then
      px="${BASH_REMATCH[1]}"
      ux="${BASH_REMATCH[2]}"
      size="${BASH_REMATCH[3]}"
      model="${BASH_REMATCH[4]}"
      hdds[(($ix+0))]="$px"
      hdds[(($ix+1))]="$ux"
      hdds[(($ix+2))]="$size"
      hdds[(($ix+3))]="$model"
      hdds[(($ix+4))]="sn"
      hdds[(($ix+5))]="/dev/sdX"
      ((ix+=6))
      ((num++))
    fi
  fi
done < <(tw_cli /c0 show)

# Loop through each drive and populate serial & path
for (( i=0; i<$num; i++ ))
do

  # Gather serial number
  # Output in form:
  # /c0/u0 serial number = YGK6ZAKA000000000000
  serial=$(tw_cli /c0/${hdds[((i*6+1))]} show serial | cut -d' ' -f5)
  hdds[((i*6+4))]="$serial"

  # Match against device path
  path=$(lsblk -o NAME,SERIAL | grep $serial | cut -d' ' -f1)
  hdds[((i*6+5))]="/dev/$path"
done

# Finally, print the result as a table
printf "%s %s %sTB %20s %20s %s\n" "${hdds[@]}"
