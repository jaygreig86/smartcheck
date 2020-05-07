# smartcheck
A simple bash script that parses the smartctl output to show predictive or imminent failures on drives

Requires smartmontools to be installed

Usage

$ chmod +x smart-check.sh

Simple output, useful to extend snmpd

$ ./smart-check

Extended output report

$ ./smart-check -d

#### Notes
* Megaraid slot count is currently hard fixed at 20 as the upper limit to avoid excessive time in searching (there's probably an easier way to retrieve the slot count somewhere without sas2ircu/sas3ircu/megacli/storcli).  The range I believe is 0 to 255
