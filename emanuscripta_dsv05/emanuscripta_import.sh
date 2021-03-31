#!/bin/csh -f

# emanuscripta_import.sh 
# Shellscript fuer Steuerung des Import von E-Manuscripta-Links
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
set source_par = "dsv05"; source $alephm_proc/set_lib_env; unset source_par;

# Arbeitsverzeichnis 
set work_dir = "$data_root/scripts/emanuscripta"

# LOG
set LOG = "$work_dir/log/emanuscripta_import.log.$date"

# Lauf fuer
set run_for = "bsub bsswa luzhb beror sozb"
#set run_for = "sozb"

# EMail-Adresse(n) - mehrere Adressen Komma-Delimited
set email = "@unibas.ch, @unibas.ch"

# --- Ende Definitionen ---------------------------------------------

echo "Running E-Manuscripta-Import for DSV05" > $LOG
echo "------------------------------" >> $LOG

cd $work_dir

# Check if Oracle running
pgrep -fl ora_db.._aleph > /dev/null
if ( $status ) then
     echo 'Oracle not running, exiting...' >> $LOG
     mailx -s "E-Manuscripta-Importlauf vom $date abgebrochen, Oracle not running" $email 
     exit
endif

# Fetch files from emanuscripta
foreach s ( $run_for )
     perl $work_dir/01_get_data_han.pl $s
end

# Process files
echo "Checking files to process for Basel UB" >> $LOG
set file_bsub = `ls -1 $work_dir/ud/emanusbau/e-manuscripta*_neu`
if ( $status ) then
    echo "Exit: no file $work_dir/ud/emanusbau/e-manuscripta*_neu found" >> $LOG
else
    echo "processing basel ub" >> $LOG
    cp $file_bsub $data_scratch/e-manuscripta_$date.bsub.seq
    mv $file_bsub $file_bsub.done
    csh -f $aleph_proc/p_manage_18 DSV05,e-manuscripta_$date.bsub.seq,e-manuscripta_$date.bsub.seq.reject,e-manuscripta_$date.bsub.seq.doc_log,OLD,,,FULL,APP,M,,,P18-Batch, > $alephe_scratch/dsv05_p_manage_18.emanuscripta_bsub.$date
endif

echo "Checking files to process for Basel SWA" >> $LOG
set file_bsswa = `ls -1 $work_dir/ud/emanusswa/e-manuscripta*_neu`
if ( $status ) then
    echo "Exit: no file $work_dir/ud/emanusswa/e-manuscripta*_neu found" >> $LOG
else
    echo "processing basel swa " >> $LOG
    cp $file_bsswa $data_scratch/e-manuscripta_$date.bsswa.seq
    mv $file_bsswa $file_bsswa.done
    csh -f $aleph_proc/p_manage_18 DSV05,e-manuscripta_$date.bsswa.seq,e-manuscripta_$date.bsswa.seq.reject,e-manuscripta_$date.bsswa.seq.doc_log,OLD,,,FULL,APP,M,,,P18-Batch, > $alephe_scratch/dsv05_p_manage_18.emanuscripta_bsswa.$date
endif

echo "Checking files to process for Luzern ZHB" >> $LOG
set file_luzhb = `ls -1 $work_dir/ud/zhb/e-manuscripta*_neu`
if ( $status ) then
    echo "Exit: no file $work_dir/ud/zhb/e-manuscripta*_neu found" >> $LOG
else
    echo "processing luzern zhb " >> $LOG
    cp $file_luzhb $data_scratch/e-manuscripta_$date.luzhb.seq
    mv $file_luzhb $file_luzhb.done
    csh -f $aleph_proc/p_manage_18 DSV05,e-manuscripta_$date.luzhb.seq,e-manuscripta_$date.luzhb.seq.reject,e-manuscripta_$date.luzhb.seq.doc_log,OLD,,,FULL,APP,M,,,P18-Batch, > $alephe_scratch/dsv05_p_manage_18.emanuscripta_luzhb.$date
endif

echo "Checking files to process for Bern Rorschach-Archiv" >> $LOG
set file_beror = `ls -1 $work_dir/ud/bes/e-manuscripta*_neu`
if ( $status ) then
    echo "Exit: no file $work_dir/ud/bes/e-manuscripta*_neu found" >> $LOG
else
    echo "processing bern rorschach archiv " >> $LOG
    cp $file_beror $data_scratch/e-manuscripta_$date.beror.seq
    mv $file_beror $file_beror.done
    csh -f $aleph_proc/p_manage_18 DSV05,e-manuscripta_$date.beror.seq,e-manuscripta_$date.beror.seq.reject,e-manuscripta_$date.beror.seq.doc_log,OLD,,,FULL,APP,M,,,P18-Batch, > $alephe_scratch/dsv05_p_manage_18.emanuscripta_beror.$date
endif

echo "Checking files to process for Solothurn Zentralbibliothek" >> $LOG
set file_sozb = `ls -1 $work_dir/ud/zbs/e-manuscripta*_neu`
if ( $status ) then
    echo "Exit: no file $work_dir/ud/zbs/e-manuscripta*_neu found" >> $LOG
else
    echo "processing solothurn zentralbibliothek" >> $LOG
    cp $file_sozb $data_scratch/e-manuscripta_$date.sozb.seq
    mv $file_sozb $file_sozb.done
    csh -f $aleph_proc/p_manage_18 DSV05,e-manuscripta_$date.sozb.seq,e-manuscripta_$date.sozb.seq.reject,e-manuscripta_$date.sozb.seq.doc_log,OLD,,,FULL,APP,M,,,P18-Batch, > $alephe_scratch/dsv05_p_manage_18.emanuscripta_sozb.$date
endif

# Show working files
echo " " >> $LOG 
echo "Workfiles processed, see alephe/scratch:" >> $LOG 
#ls -lrt $work_dir/ud/bau_1/ | tail -6
#ls -lrt $work_dir/ud/bes_1/ | tail -6
#ls -al $data_scratch/ | grep $date
ls -al $alephe_scratch | grep e-manuscripta_$date >> $LOG

# Sending Mail about job
cat $LOG | mailx -s "E-Manuscripta-Importlauf vom $date done" $email
exit

