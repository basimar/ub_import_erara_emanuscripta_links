#!/bin/csh -f
# Setzt Tag fuer E-Rara-Importlauf fest und ruft Script auf
# Der E-Rara-Importlauf laeuft jeden ersten Montag im Monat fuer DSV01.

set datum = `date +%Y%m%d`

if (`date +%a` == 'Mon' && `date +%d` < 8 ) then
   cd $dsv01_dev/dsv01/scripts/erara
   erara_import.sh > log/erara_lauf_$datum.log
else
   echo "Kein E-Rara-Import-Lauf heute (jeden ersten Montag im Monat)"
   exit
endif

