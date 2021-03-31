#!/bin/csh -f
# Setzt Tag fuer E-Manuscripta-Importlauf fuer DSV01 fest und ruft Script auf
# Der E-Manuscripta-Importlauf laeuft jeden ersten Montag im Monat fuer DSV01.

set datum = `date +%Y%m%d`

if (`date +%a` == 'Mon' && `date +%d` < 8 ) then
   cd $dsv01_dev/dsv01/scripts/emanuscripta
   emanuscripta_import.sh > log/emanuscripta_lauf_$datum.log
else
   echo "Kein E-Manuscripta (DSV01)-Import-Lauf heute (jeden ersten Montag im Monat)"
   exit
endif

