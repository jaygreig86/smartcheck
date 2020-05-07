#!/usr/bin/env bash
# smart-check.sh
#
# Purpose:
#   simple bash script that parses the output provided by smartctl
#   to show relevant information about predictive failures
#   things are wrong.
#
# Original Author: James Greig
# Licence: GNU GPL v3

POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -d|--debug)
    DEBUG=1
    shift # past argument
    shift # past value
    ;;
esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters

#What system is this?
# 3ware? smartctl -a -d 3ware,1 /dev/twl0 -T permissive
# for i in `ls /dev/sd*|egrep '^(\/)dev(\/)sd[a-z]$'`; do smartctl -a $i | egrep -i 'serial|Reallocated_Sector|wear_leveling'; done
# lsi megaraid:-  smartctl -a -d megaraid,6 /dev/sda -T permissive

#disks=($(ls /dev/sd*|egrep '^(\/)dev(\/)sd[a-z]$'))

function smartcheck()
{
        error=0
        # Wear on SSDs via SATA

        smartoutput=$(smartctl -a $1)
        serial=`echo "$smartoutput" | egrep "Serial Number:|Serial number:" | awk '{print $3}'`
        if [ ${DEBUG} ] &&  [ ${serial} ]
        then
                echo -e "---"
                echo -e "\e[0;40mScanning $1 Serial: ${serial} \e[0m"
        fi

        # SSD Wear Level

        #var=`smartctl -a $1 | grep Wear_Leveling | awk '{print $4}' | sed 's/^0\|^00//'`
        var=`echo "$smartoutput" | grep Wear_Leveling | awk '{print $4}' | sed 's/^0\|^00//'`
        if [[ ${var#0} -lt 20 ]] && [[ ${var#0} -gt 0 ]]
        then
                echo -e "\e[0;41m$1 is at ${var#0}% SSD wear\e[0m"
                error=$(($error + 1))
        elif [ ${DEBUG} ] && [[ ${var#0} -gt 0 ]]
        then
                echo -e "\e[30;42m$1 is at ${var#0}% SSD wear\e[0m"
        fi


        # Reallocated sectors on SATA drives

        #var=`smartctl -a $1 | grep Reallocated_Sector | awk '{print $10}' `
        var=`echo "$smartoutput" | grep Reallocated_Sector | awk '{print $10}' `
        if [[ $var -gt 0 ]]
        then
                echo -e "\e[0;41m$1 has $var Sector Errors\e[0m"
                error=$(($error + 1))
        elif [ ${DEBUG} ] && [[ $var =~ ^[0-9]+$  ]]
        then
                echo -e "\e[30;42m$1 has $var Sector Errors\e[0m"
        fi

        # Early Warning Offline_Uncorrectable

        #var=`smartctl -a $1 | grep Offline_Uncorrectable | awk '{print $10}' `
        var=`echo "$smartoutput" | grep Offline_Uncorrectable | awk '{print $10}' `
        if [[ $var -gt 0 ]]
        then
                echo -e "\e[0;41m$1 has $var Offline Uncorrectable Errors\e[0m"
                error=$(($error + 1))
        elif [ ${DEBUG} ] && [[ $var =~ ^[0-9]+$  ]]
        then
                echo -e "\e[30;42m$1 has $var Offline Uncorrectable Errors\e[0m"
        fi


        # SAS Read errors

        #var=`smartctl -a $1 | egrep "read:" | awk '{print $8}'`
        var=`echo "$smartoutput" | egrep "read:" | awk '{print $8}'`
        if [[ $var -gt 0 ]]
        then
                echo -e "\e[0;41m$1 $var SAS Read Errors\e[0m"
                error=$(($error + 1))
        elif [ ${DEBUG} ] && [[ $var =~ ^[0-9]+$ ]]
        then
                echo -e "\e[30;42m$1 $var SAS Read Errors\e[0m"
        fi

        # SAS Write errors

        #var=`smartctl -a $1 | egrep "write:" | awk '{print $8}'`
        var=`echo "$smartoutput"  | egrep "write:" | awk '{print $8}'`
        if [[ $var -gt 0 ]]
        then
                echo -e "\e[0;41m$1 $var SAS Write Errors\e[0m"
                error=$(($error + 1))
        elif [ ${DEBUG} ] && [[ $var =~ ^[0-9]+$ ]]
        then
                echo -e "\e[30;42m$1 $var SAS Write Errors\e[0m"
        fi

        # SAS post factory defects

        #var=`smartctl -a $1 | egrep "write:" | awk '{print $8}'`
        var=`echo "$smartoutput"  | grep -i "grown defect" | sed 's/Elements in grown defect list: //'`
        if [[ $var -gt 0 ]] && [ ${DEBUG} ]
        then
                sleep 0
                echo -e "\e[30;43m$1 $var SAS accumulated defects\e[0m"
                #error=$(($error + 1))
        elif [ ${DEBUG} ] && [[ $var =~ ^[0-9]+$ ]]
        then
                echo -e "\e[30;42m$1 $var SAS accumulated defects\e[0m"
        fi


        return $error
}
if [ ! -x "$(command -v smartctl)" ]
then
        echo "Error: Smartctl command not found"
        exit 1
fi

agerror=0

# Check disks attached to the board directly or in passthrough
#for i in `ls /dev/sd*|egrep '^(\/)dev(\/)sd[a-z]$'`;
for i in `find /dev -type b -name 'sd*' | egrep '^(\/)dev(\/)sd[a-z]$'`;
do
        smartcheck $i $DEBUG
        rval=$?
        agerror=$(($agerror + $rval))
done
# Check disks attached to the board directly or in passthrough (BSD)
#for i in `ls /dev/pass*|egrep '^(\/)dev(\/)pass[0-9]+$'`;
for i in `find /dev -type c -name 'pass*' | egrep '^(\/)dev(\/)pass[0-9]$'`;
do
        smartcheck "-d sat $i" $DEBUG
        rval=$?
        agerror=$(($agerror + $rval))
done

# Check disks behind LSISAS2008 LV
#for i in `ls /dev/sg*|egrep '^(\/)dev(\/)sg[0-9]+$'`;
for i in `find /dev -type c -name 'sg*' | egrep '^(\/)dev(\/)sg[0-9]+$'`;
do
        smartcheck $i $DEBUG
        rval=$?
        agerror=$(($agerror + $rval))
done
# Check disks behind a 3ware card
for i in `seq 0 20`
do
        smartcheck "-d 3ware,$i /dev/twl0 -T permissive" $DEBUG
        rval=$?
        agerror=$(($agerror + $rval))
done

# Check disks behind an lsi card - fixed at sda at the moment
for i in `seq 0 20`
do
        smartcheck "-d megaraid,$i /dev/sda -T permissive" $DEBUG
        rval=$?
        agerror=$(($agerror + $rval))
done

if [[ $agerror -gt 0 ]]
then
        echo -e "\e[0;41m$agerror Errors were found\e[0m"
        exit $agerror
else
        echo -e "\e[30;42mNo errors were found\e[0m"
        exit 0
fi
