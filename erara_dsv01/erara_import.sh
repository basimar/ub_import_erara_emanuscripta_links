#!/bin/csh -f

# erara_import.sh 
# Shellscript fuer Steuerung des Import von E-Rara-Links
# HINWEISE: Achtung, Verzeichnispfade sind ggf. verbundspezifisch
# 1. Environment der library setzen
# 2. Folgende Verzeichnisse muessen vorhanden sein, oder umdefiniert werden:
#          $data_root/import_files/erara/ud/
#          $data_root/import_files/erara/log
# 3. Verbund muss definiert werden ($run_for)
# 6. Das Script soll und kann nicht versehentlich zweimal hintereinander am selben Tag laufen. 
#
# History:
# 03.03.2014    erstellt / blu
# 22.02.2018    Mailadresse angepasst / fbo

# --- Start Definitionen --------------------------------------------

# Datum
if ($#argv == 0) then
   set date = `date +'%Y-%m-%d'`
else
     echo "usage: csh -f erara_import.sh"
     echo "Date is set to the current date by the procedure"
     exit
   endif
endif

# Environment der library setzen, mit der die ADAM-Objekt verknuepft sind
set source_par = "dsv01"; source $alephm_proc/set_lib_env; unset source_par;

# Datenverzeichis 
set work_dir = "$data_root/scripts/erara"

# LOG
set LOG = "$work_dir/log/erara_import.log.$date"

# Lauf fuer
set run_for = "basel bern mab"

# EMail-Adresse(n) - mehrere Adressen Komma-Delimited
set email = "@unibas.ch,@ub.unibe.ch"

# --- Ende Definitionen ---------------------------------------------

echo "Running Erara-Import for DSV01" > $LOG
echo "------------------------------" >> $LOG

cd $work_dir

# Check if Oracle running
pgrep -fl ora_db.._aleph > /dev/null
if ( $status ) then
     echo 'Oracle not running, exiting...' >> $LOG
     mailx -s "Erara Importlauf vom $date abgebrochen, Oracle not running" $email 
     exit
endif

# Fetch files from erara
foreach s ( $run_for )
     perl $work_dir/01_get_data.pl $s
end

# Process files
echo "Checking files to process for basel" >> $LOG
set file_basel = `ls -1 $work_dir/ud/bau_1/e-rara*_neu`
if ( $status ) then
    echo "Exit: no file $work_dir/ud/bau_1/e-rara*_neu found" >> $LOG
else
    echo "processing basel" >> $LOG
    cp $file_basel $data_scratch/e-rara_$date.bs.seq
    mv $file_basel $file_basel.done
    csh -f $aleph_proc/p_manage_18 DSV01,e-rara_$date.bs.seq,e-rara_$date.bs.seq.reject,e-rara_$date.bs.seq.doc_log,OLD,,,FULL,APP,M,,,P18-Batch, > $alephe_scratch/dsv01_p_manage_18.erara_bs.$date
endif

echo "Checking files to process for mab" >> $LOG
set file_mab = `ls -1 $work_dir/ud/mab/e-rara*_neu`
if ( $status ) then
    echo "Exit: no file $work_dir/ud/mab/e-rara*_neu found" >> $LOG
else
    echo "processing mab" >> $LOG
    cp $file_mab $data_scratch/e-rara_$date.mab.seq
    mv $file_mab $file_mab.done
    csh -f $aleph_proc/p_manage_18 DSV01,e-rara_$date.mab.seq,e-rara_$date.mab.seq.reject,e-rara_$date.mab.seq.doc_log,OLD,,,FULL,APP,M,,,P18-Batch, > $alephe_scratch/dsv01_p_manage_18.erara_mab.$date
endif

echo "Checking files to process for bern" >> $LOG
set file_bern = `ls -1 $work_dir/ud/bes_1/e-rara*_neu`
if ( $status ) then
    echo "Exit: no file $work_dir/ud/bes_1/e-rara*_neu found" >> $LOG
else
    echo "processing bern" >> $LOG
    cp $file_bern $data_scratch/e-rara_$date.be.seq
    mv $file_bern $file_bern.done
    csh -f $aleph_proc/p_manage_18 DSV01,e-rara_$date.be.seq,e-rara_$date.be.seq.reject,e-rara_$date.be.seq.doc_log,OLD,,,FULL,APP,M,,,P18-Batch, > $alephe_scratch/dsv01_p_manage_18.erara_be.$date
endif

# Show working files
echo " " >> $LOG 
echo "Workfiles processed, see alephe/scratch:" >> $LOG 
#ls -lrt $work_dir/ud/bau_1/ | tail -6
#ls -lrt $work_dir/ud/bes_1/ | tail -6
#ls -al $data_scratch/ | grep $date
ls -al $alephe_scratch | grep e-rara_$date >> $LOG

# Sending Mail about job
cat $LOG | mailx -s "Erara Importlauf vom $date done" $email
exit

