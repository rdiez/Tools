#!/bin/bash

# This script shows some system memory statistics specifically
# aimed at zram swap partitions.
#
# Version 1.01
#
# Copyright (c) 2014 R. Diez - Licensed under the GNU AGPLv3.
#
# Warning: Stats data is read from several unsynchronised pseudo files, each of which can change
#          at any point in time, therefore the results are not completely reliable.

set -o errexit
set -o nounset
set -o pipefail


abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit 1
}


PROC_MEMINFO_FILENAME="/proc/meminfo"

parse_proc_meminfo_value_in_kib ()
{
  local PARTS
  local -i VALUE
  local UNIT

  # Split on blanks.
  IFS=$' \t' PARTS=($1)

  if [ ${#PARTS[@]} -ne 2 ]; then
    abort "Invalid data format in file \"$PROC_MEMINFO_FILENAME\"."
  fi

  VALUE="${PARTS[0]}"
  UNIT="${PARTS[1]}"

  if [[ $UNIT != "kB" ]]; then
    abort "Unexpected unit \"$UNIT\" in file \"$PROC_MEMINFO_FILENAME\"."
  fi

  echo "$VALUE"
}


print_percent()
{
  local -i BASE="$1"
  local -i SMALLER_VALUE="$2"

  if [[ $BASE -eq 0 ]]; then
    echo "----%"
  else
    local INTEGER="$(( SMALLER_VALUE * 100 / BASE ))"
    local FRACTIONAL="$(( ( SMALLER_VALUE * 1000 / BASE ) % 10))"

    printf "%3s%s%s%%" "${INTEGER}" "${LOCALE_FRACTIONAL_SEPARATOR}" "${FRACTIONAL}"
  fi
}


print_rate()
{
  local -i BASE="$1"
  local -i SMALLER_VALUE="$2"

  if [[ $SMALLER_VALUE -eq 0 ]]; then
    echo "---"
  else
    local INTEGER="$(( BASE / SMALLER_VALUE ))"
    local FRACTIONAL="$(( ( BASE * 100 / SMALLER_VALUE ) % 100))"

    printf "%s%s%s" "${INTEGER}" "${LOCALE_FRACTIONAL_SEPARATOR}" "${FRACTIONAL}"
  fi
}


# ------ Entry Point ------

# Find out locale information.

LOCALE_CONTENTS="$(locale -v LC_NUMERIC)"
# Split on newline characters.
IFS=$'\n' LOCALE_LINES=($LOCALE_CONTENTS)
LOCALE_FRACTIONAL_SEPARATOR="${LOCALE_LINES[0]}"
# LOCALE_THOUSANDS_SEPARATOR="${LOCALE_LINES[1]}"

# Read the whole /proc/swaps file at once.
PROC_SWAPS_FILENAME="/proc/swaps"
PROC_SWAPS_CONTENTS="$(<$PROC_SWAPS_FILENAME)"

# Split on newline characters.
# Bash 4 has 'readarray', or we have used something like [ IFS=$'\n' read -rd '' -a PROC_SWAPS_LINES <<<"$PROC_SWAPS_CONTENTS" ] instead.
IFS=$'\n' PROC_SWAPS_LINES=($PROC_SWAPS_CONTENTS)


# The first line contains the column headers, so skip it.

PROC_SWAPS_LINE_COUNT="${#PROC_SWAPS_LINES[@]}"

if [ "$PROC_SWAPS_LINE_COUNT" -le 1 ]; then
  abort "No swap files found."
fi

declare -i AT_LEAST_ONE_ZRAM_FOUND=0
declare -i AT_LEAST_ONE_ACTIVE_ZRAM_FOUND=0

declare -i TOTAL_ZRAM_ORIG_DATA_SIZE=0
declare -i TOTAL_ZRAM_COMPR_DATA_SIZE=0
declare -i TOTAL_ZRAM_MEM_USED_TOTAL=0
declare -i TOTAL_ZRAM_DISKSIZE=0
declare -i TOTAL_ZRAM_ZERO_PAGES=0

declare -i TOTAL_OTHER_FILE_USED_KIB=0
declare -i TOTAL_ZRAM_SWAP_FILE_SIZE_KIB=0
declare -i TOTAL_ZRAM_SWAP_FILE_USED_KIB=0

for ((i=1; i<PROC_SWAPS_LINE_COUNT; i++)); do

  # Split on blanks.
  IFS=$' \t' PROC_SWAPS_LINE_FIELDS=(${PROC_SWAPS_LINES[$i]})

  # We expect at least 5 fields.
  PROC_SWAPS_LINE_FIELD_COUNT="${#PROC_SWAPS_LINE_FIELDS[@]}"
  if [ "$PROC_SWAPS_LINE_FIELD_COUNT" -lt 5 ]; then
    abort "File \"$PROC_SWAPS_FILENAME\" has an invalid format."
  fi

  SWAP_FILE_NAME="${PROC_SWAPS_LINE_FIELDS[0]}"
  SWAP_FILE_SIZE="${PROC_SWAPS_LINE_FIELDS[2]}"
  SWAP_FILE_USED="${PROC_SWAPS_LINE_FIELDS[3]}"

  # We hope that only zram swap devices are called "zram" followed by a number.
  REGEX="zram[[:digit:]]+\$"
  if ! [[ $SWAP_FILE_NAME =~ $REGEX ]]; then
    TOTAL_OTHER_FILE_USED_KIB=$(( TOTAL_OTHER_FILE_USED_KIB + SWAP_FILE_USED ))
    continue
  fi

  AT_LEAST_ONE_ZRAM_FOUND=1

  # Only take into consideration initialised devices.
  ZRAM_DIR="/sys$(udevadm info --query=path --name="$SWAP_FILE_NAME")"
  INITSTATE="$(<"$ZRAM_DIR/initstate")"
  if [[ $INITSTATE -ne 1 ]]; then
    continue
  fi

  AT_LEAST_ONE_ACTIVE_ZRAM_FOUND=1

  TOTAL_ZRAM_SWAP_FILE_SIZE_KIB="$(( TOTAL_ZRAM_SWAP_FILE_SIZE_KIB + SWAP_FILE_SIZE ))"
  TOTAL_ZRAM_SWAP_FILE_USED_KIB="$(( TOTAL_ZRAM_SWAP_FILE_USED_KIB + SWAP_FILE_USED ))"

  ORIG_DATA_SIZE="$(<"$ZRAM_DIR/orig_data_size")"
  COMPR_DATA_SIZE="$(<"$ZRAM_DIR/compr_data_size")"
  MEM_USED_TOTAL="$(<"$ZRAM_DIR/mem_used_total")"
  DISKSIZE="$(<"$ZRAM_DIR/disksize")"
  ZERO_PAGES="$(<"$ZRAM_DIR/zero_pages")"

  TOTAL_ZRAM_ORIG_DATA_SIZE=$(( TOTAL_ZRAM_ORIG_DATA_SIZE + ORIG_DATA_SIZE ))
  TOTAL_ZRAM_COMPR_DATA_SIZE=$(( TOTAL_ZRAM_COMPR_DATA_SIZE + COMPR_DATA_SIZE ))
  TOTAL_ZRAM_MEM_USED_TOTAL=$(( TOTAL_ZRAM_MEM_USED_TOTAL + MEM_USED_TOTAL ))
  TOTAL_ZRAM_DISKSIZE=$(( TOTAL_ZRAM_DISKSIZE + DISKSIZE ))
  TOTAL_ZRAM_ZERO_PAGES=$(( TOTAL_ZRAM_ZERO_PAGES + ZERO_PAGES ))

done

if [[ AT_LEAST_ONE_ZRAM_FOUND -eq 0 ]]; then
  abort "No zram swap partitions found."
fi

if [[ AT_LEAST_ONE_ACTIVE_ZRAM_FOUND -eq 0 ]]; then
  abort "No initialised zram swap partitions found."
fi


# Read several global system memory stats.

while IFS=":" read -r NAME VALUE
do
  case "$NAME" in
   MemTotal) SYS_MEM_TOTAL_KIB="$(parse_proc_meminfo_value_in_kib "$VALUE")";;
   MemFree)  SYS_MEM_FREE_KIB="$(parse_proc_meminfo_value_in_kib "$VALUE")";;
   Buffers)  SYS_BUFFERS_KIB="$(parse_proc_meminfo_value_in_kib "$VALUE")";;
   Cached)   SYS_CACHED_KIB="$(parse_proc_meminfo_value_in_kib "$VALUE")";;
  esac
done <"$PROC_MEMINFO_FILENAME"

# We may need to switch to the external printf tool in the future.
# PRINTF_TOOL="$(which "printf")"
PRINTF_TOOL="printf"
UNIT="MiB"

# There is a little overhead at the beginning of the swap file. Allow for a 1 % difference.
declare -i TOTAL_ZRAM_DISKSIZE_KIB=$(( TOTAL_ZRAM_DISKSIZE / 1024 ))

if [[ $TOTAL_ZRAM_SWAP_FILE_SIZE_KIB -gt $TOTAL_ZRAM_DISKSIZE_KIB ]]; then
  abort "$(printf "The zram swap file size reported by the system (%'i KiB) is greater than zram's advertised disk size (%'i KiB). Something is wrong." "$TOTAL_ZRAM_SWAP_FILE_SIZE_KIB" "$TOTAL_ZRAM_DISKSIZE_KIB" )"
fi

# The swap file header occupies normally the first 4 KiB (one page).
declare -i SWAPFILE_HEADER_SIZE=$(( TOTAL_ZRAM_DISKSIZE_KIB - TOTAL_ZRAM_SWAP_FILE_SIZE_KIB ))
SWAP_FILE_DEVIATION_PERCENT="$(( SWAPFILE_HEADER_SIZE * 100 / TOTAL_ZRAM_DISKSIZE_KIB ))"

if [[ $SWAP_FILE_DEVIATION_PERCENT -gt 1 ]]; then
  abort "$(printf "The difference between the zram swap file size reported by the system (%'i KiB) and zram's advertised disk size (%'i KiB) is too big. Something is wrong." "$TOTAL_ZRAM_SWAP_FILE_SIZE_KIB" "$TOTAL_ZRAM_DISKSIZE_KIB" )"
fi

declare -i PAGESIZE
PAGESIZE="$(getconf PAGESIZE)"
declare -i ADVERTISED_SWAP_SPACE_MIB="$(( TOTAL_ZRAM_DISKSIZE_KIB / 1024 ))"
declare -i TOTAL_ZRAM_ZERO_PAGES_SIZE="$(( TOTAL_ZRAM_ZERO_PAGES * PAGESIZE ))"
declare -i TOTAL_ZRAM_ZERO_PAGES_SIZE_KIB="$(( TOTAL_ZRAM_ZERO_PAGES_SIZE / 1024 ))"
declare -i TOTAL_ZRAM_ZERO_PAGES_SIZE_MIB="$(( TOTAL_ZRAM_ZERO_PAGES_SIZE_KIB / 1024 ))"
declare -i TOTAL_ZRAM_ORIG_DATA_SIZE_MIB="$(( TOTAL_ZRAM_ORIG_DATA_SIZE / 1024 / 1024 ))"

# I looked at zram's source code in Linux Kernel version 3.14.4, and it seems that
# orig_data_size (stats.pages_stored) and compr_data_size (stats.compr_size) do not take
# zeroed pages into account.
declare -i ZRAM_USED_FROM_ADVERTISED="$(( SWAPFILE_HEADER_SIZE + TOTAL_ZRAM_ORIG_DATA_SIZE + TOTAL_ZRAM_ZERO_PAGES * PAGESIZE ))"
declare -i ZRAM_USED_FROM_ADVERTISED_KIB="$(( ZRAM_USED_FROM_ADVERTISED / 1024 ))"
declare -i ZRAM_USED_FROM_ADVERTISED_MIB="$(( ZRAM_USED_FROM_ADVERTISED_KIB / 1024 ))"

# If the kernel accounts for some usage, but zram has not seen the corresponding data pages,
# that means the kernel has allocated the pages but not written them yet. Those pages
# are allocated but actually unused.
declare -i RESERVED_BUT_UNUSED_KIB="$(( TOTAL_ZRAM_SWAP_FILE_USED_KIB - ZRAM_USED_FROM_ADVERTISED / 1024 ))"
declare -i RESERVED_BUT_UNUSED_MIB="$(( RESERVED_BUT_UNUSED_KIB / 1024 ))"

declare -i TOTAL_ZRAM_SWAP_FREE_KIB=$(( TOTAL_ZRAM_SWAP_FILE_SIZE_KIB - TOTAL_ZRAM_SWAP_FILE_USED_KIB ))
declare -i TOTAL_ZRAM_SWAP_FREE_MIB=$(( TOTAL_ZRAM_SWAP_FREE_KIB / 1024 ))

declare -i TOTAL_OTHER_FILE_USED_MIB=$(( TOTAL_OTHER_FILE_USED_KIB / 1024 ))

# 1 TiB RAM is 1,048,576 MiB, so we would need room for 7 characters plus separators,
# but it is rare to find so much RAM yet, so make it a little smaller,
# so that the resulting columns are not too far away from each other.
declare -i MAX_VAL_WIDTH=7
PRTCOLVAL="%'${MAX_VAL_WIDTH}i"

declare -i SYS_MEM_TOTAL_MIB=$(( SYS_MEM_TOTAL_KIB / 1024 ))
declare -i TOTAL_ZRAM_MEM_USED_TOTAL_KIB=$(( TOTAL_ZRAM_MEM_USED_TOTAL / 1024 ))
declare -i TOTAL_ZRAM_MEM_USED_TOTAL_MIB=$(( TOTAL_ZRAM_MEM_USED_TOTAL_KIB / 1024 ))
declare -i TOTAL_ZRAM_COMPR_DATA_SIZE_MIB=$(( TOTAL_ZRAM_COMPR_DATA_SIZE / 1024 / 1024 ))

declare -i ADMIN_OVERHEAD=$(( TOTAL_ZRAM_MEM_USED_TOTAL - TOTAL_ZRAM_COMPR_DATA_SIZE ))
declare -i ADMIN_OVERHEAD_MIB=$(( ADMIN_OVERHEAD / 1024 / 1024 ))

declare -i ORIG_PLUS_ZERO_SIZE=$(( TOTAL_ZRAM_ZERO_PAGES_SIZE + TOTAL_ZRAM_ORIG_DATA_SIZE ))

declare -i NORMAL_USAGE_KIB=$(( SYS_MEM_TOTAL_KIB - TOTAL_ZRAM_MEM_USED_TOTAL_KIB - SYS_BUFFERS_KIB - SYS_CACHED_KIB - SYS_MEM_FREE_KIB ))

{
  "$PRINTF_TOOL" "Physical memory:\\t$PRTCOLVAL $UNIT\\n" "$SYS_MEM_TOTAL_MIB"
  "$PRINTF_TOOL" "Allocated by zram:\\t$PRTCOLVAL $UNIT (%s)\\n" "$TOTAL_ZRAM_MEM_USED_TOTAL_MIB" "$(print_percent "$SYS_MEM_TOTAL_KIB" "$(( TOTAL_ZRAM_MEM_USED_TOTAL / 1024 ))")"
  "$PRINTF_TOOL" "Normal usage:\\t$PRTCOLVAL $UNIT (%s)\\n" "$(( NORMAL_USAGE_KIB / 1024 ))" "$(print_percent "$SYS_MEM_TOTAL_KIB" "$NORMAL_USAGE_KIB")"
  "$PRINTF_TOOL" "Application I/O buffers:\\t$PRTCOLVAL $UNIT (%s)\\n" "$(( SYS_BUFFERS_KIB / 1024 ))"  "$(print_percent "$SYS_MEM_TOTAL_KIB" "$SYS_BUFFERS_KIB")"
  "$PRINTF_TOOL" "System file cache:\\t$PRTCOLVAL $UNIT (%s)\\n" "$(( SYS_CACHED_KIB / 1024 ))" "$(print_percent "$SYS_MEM_TOTAL_KIB" "$SYS_CACHED_KIB")"
  "$PRINTF_TOOL" "Free:\\t$PRTCOLVAL $UNIT (%s)\\n" "$(( SYS_MEM_FREE_KIB / 1024 ))" "$(print_percent "$SYS_MEM_TOTAL_KIB" "$SYS_MEM_FREE_KIB")"
} | column -t -s $'\t'

"$PRINTF_TOOL" "\\n"

{
  "$PRINTF_TOOL" "zram advertised device size:\\t$PRTCOLVAL $UNIT (%s of physical RAM)\\n" "$ADVERTISED_SWAP_SPACE_MIB" "$(print_percent "$SYS_MEM_TOTAL_KIB" "$TOTAL_ZRAM_DISKSIZE_KIB")"
  "$PRINTF_TOOL" "zram used size:\\t$PRTCOLVAL $UNIT (%s of advertised)\\n" "$ZRAM_USED_FROM_ADVERTISED_MIB" "$(print_percent "$TOTAL_ZRAM_DISKSIZE_KIB" "$(( ZRAM_USED_FROM_ADVERTISED / 1024 ))")"
  "$PRINTF_TOOL" "zram reserved but unused:\\t$PRTCOLVAL $UNIT (%s of advertised)\\n" "$RESERVED_BUT_UNUSED_MIB" "$(print_percent "$TOTAL_ZRAM_DISKSIZE_KIB" "$RESERVED_BUT_UNUSED_KIB")"
  "$PRINTF_TOOL" "zram free:\\t$PRTCOLVAL $UNIT (%s of advertised)\\n" "$TOTAL_ZRAM_SWAP_FREE_MIB" "$(print_percent "$TOTAL_ZRAM_DISKSIZE_KIB" "$TOTAL_ZRAM_SWAP_FREE_KIB")"
  "$PRINTF_TOOL" "Additional non-zram swap used:\\t$PRTCOLVAL $UNIT (%s in addition)\\n" "$TOTAL_OTHER_FILE_USED_MIB" "$(print_percent "$TOTAL_ZRAM_DISKSIZE_KIB" "$TOTAL_OTHER_FILE_USED_KIB")"
} | column -t -s $'\t'

"$PRINTF_TOOL" "\\n"

"$PRINTF_TOOL" "zram compression statistics:\\n"
{
  "$PRINTF_TOOL" "Zeroed pages:\\t$PRTCOLVAL $UNIT (%s of used swap)\\n" "$TOTAL_ZRAM_ZERO_PAGES_SIZE_MIB" "$(print_percent "$ZRAM_USED_FROM_ADVERTISED_KIB" "$TOTAL_ZRAM_ZERO_PAGES_SIZE_KIB")"
  "$PRINTF_TOOL" "Original data size:\\t$PRTCOLVAL $UNIT\\n" "$TOTAL_ZRAM_ORIG_DATA_SIZE_MIB"
  "$PRINTF_TOOL" "Compressed data size:\\t$PRTCOLVAL $UNIT (%s of orig, rate %s)\\n" "$TOTAL_ZRAM_COMPR_DATA_SIZE_MIB" "$(print_percent "$TOTAL_ZRAM_ORIG_DATA_SIZE" "$TOTAL_ZRAM_COMPR_DATA_SIZE")" "$(print_rate "$TOTAL_ZRAM_ORIG_DATA_SIZE" "$TOTAL_ZRAM_COMPR_DATA_SIZE")"
  "$PRINTF_TOOL" "Admin overhead:\\t$PRTCOLVAL $UNIT (%s of compressed size)\\n" "$ADMIN_OVERHEAD_MIB" "$(print_percent "$TOTAL_ZRAM_COMPR_DATA_SIZE" "$ADMIN_OVERHEAD")"
  "$PRINTF_TOOL" "In other words, lost:\\t$PRTCOLVAL $UNIT of RAM,\\n" "$TOTAL_ZRAM_MEM_USED_TOTAL_MIB"
  "$PRINTF_TOOL" "          and gained:\\t$PRTCOLVAL $UNIT of fast swap.\\n" "$(( ORIG_PLUS_ZERO_SIZE / 1024 / 1024 ))"
  # Formula: (zero+orig)/(compr+overh)
  "$PRINTF_TOOL" "Overall compr swap size:\\t%s of orig used size, rate %s\\n" "$(print_percent "$ORIG_PLUS_ZERO_SIZE" "$TOTAL_ZRAM_MEM_USED_TOTAL")" "$(print_rate "$ORIG_PLUS_ZERO_SIZE" "$TOTAL_ZRAM_MEM_USED_TOTAL")"
} | column -t -s $'\t'
