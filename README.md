# smartcheck
A simple bash script that parses the smartctl output to show predictive or imminent failures on drives

Requires smartmontools to be installed

Usage

$ chmod +x smart-check.sh

Simple output, useful to extend snmpd

$ ./smart-check

Extended output report

$ ./smart-check -d
