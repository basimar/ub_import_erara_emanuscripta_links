#!/bin/csh -f

# emanuscripta_import.sh 
# Shellscript fuer Steuerung des Import von E-Manuscripta-Links in DSV01
# HINWEISE: Achtung, Verzeichnispfade sind ggf. verbundspezifisch
# 1. Environment der library setzen
# 2. Folgende Verzeichnisse muessen vorhanden sein, oder umdefiniert werden:
#          $data_root/scripts/emanuscripta/data/
#          $data_root/scripts/emanuscripta/ud/
#          $data_root/scripts/emanuscripta/log/
# 3. Verbund muss definiert werden ($run_for)
# 4. Das Verzeichnis, in dem die Perl-Scripte 01_get_data.pl und 02_check_in_z00_data.pl liegen, muss definiert werden ($script_dir).
# 6. Das Script soll und kann nicht versehentlich zweimal hintereinander am selben Tag laufen. 
#
# Stand: 15.12.2014, basil.marti@unibas.ch
# Basiert auf erara_import.sh von Bernd Luchner
# Adaption fuer e-manuscripta import nach DSV01 28.09.2018/bmt

# --- Start Definitionen --------------------------------------------

# Datum
if ($#argv == 0) then
   set date = `date +'%Y-%m-%d'`
else
     echo "usage: csh -f emanuscripta_import.sh"
     echo "Date is set to the current date by the procedure"
     exit
   endif
endif

# Environment der library setzen, mit der die ADAM-Objekt verknuepft sind
set source_par = "dsv01"; source $alephm_proc/set_lib_env; unset source_par;

# Arbeitsverzeichnis 
set work_dir = "$data_root/scripts/emanuscripta"

# LOG
set LOG = "$work_dir/log/emanuscripta_import_dsv01.log.$date"

# Lauf fuer
set run_for = "bsub"

# EMail-Adresse(n) - mehrere Adressen Komma-Delimited
set email = "@unibas.ch,@unibas.ch"

# --- Ende Definitionen ---------------------------------------------

echo "Running E-Manuscripta-Import for DSV01" > $LOG
echo "------------------------------" >> $LOG

cd $work_dir

# Check if Oracle running
pgrep -fl ora_db.._aleph > /dev/null
if ( $status ) then
     echo 'Oracle not running, exiting...' >> $LOG
     mailx -s "E-Manuscripta-Importlauf (DSV01) vom $date abgebrochen, Oracle not running" $email 
     exit
endif

# Fetch files from emanuscripta
foreach s ( $run_for )
     perl $work_dir/01_get_data_dsv01.pl $s
end

# Process files
echo "Checking files to process for Basel UB" >> $LOG
set file_bsub = `ls -1 $work_dir/ud/emanusbau1/e-manuscripta*_neu`
if ( $status ) then
    echo "Exit: no file $work_dir/ud/emanusbau1/e-manuscripta*_neu found" >> $LOG
else
    echo "processing basel ub" >> $LOG
    cp $file_bsub $data_scratch/e-manuscripta_dsv01_$date.bsub.seq
    mv $file_bsub $file_bsub.done
    csh -f $aleph_proc/p_manage_18 DSV01,e-manuscripta_dsv01_$date.bsub.seq,e-manuscripta_dsv01_$date.bsub.seq.reject,e-manuscripta_dsv01_$date.bsub.seq.doc_log,OLD,,,FULL,APP,M,,,P18-Batch, > $alephe_scratch/dsv01_p_manage_18.emanuscripta_dsv01_bsub.$date
endif

# Show working files
echo " " >> $LOG 
echo "Workfiles processed, see alephe/scratch:" >> $LOG 
ls -al $alephe_scratch | grep e-manuscripta_dsv01_$date >> $LOG

# Sending Mail about job
cat $LOG | mailx -s "E-Manuscripta-Importlauf vom $date done" $email
exit

