#!/bin/csh -f
# Setzt Tag fuer E-Manuscripta-Importlauf fest und ruft Script auf
# Der E-Manuscripta-Importlauf laeuft jeden ersten Montag im Monat fuer DSV05.

set datum = `date +%Y%m%d`

if (`date +%a` == 'Mon' && `date +%d` < 8 ) then
   cd $dsv05_dev/dsv05/scripts/emanuscripta
   emanuscripta_import.sh > log/emanuscripta_lauf_$datum.log
else
   echo "Kein E-Manuscripta-Import-Lauf heute (jeden ersten Montag im Monat)"
   exit
endif

