# Creat CSV for entire session

QCDIR=/projects/b1134/processed/boldqc

for i in `ls $QCDIR/*/sub-*/`
do
echo "Merging QC run reports for $i into session report"
done
projectnm=$(realpath $i | awk -F 'boldqc/' '{print $2}'  | cut -d'/' -f1)
SUB=$(realpath $i | awk -F 'sub-' '{print $2}' | cut -d'/' -f1)
SESS=$(realpath $i | awk -F 'ses-' '{print $2}' | cut -d'/' -f1)

printf '%s\n %s\n %s\n %s\n %s\n %s\n %s\n %s\n %s\n %s\n %s\n %s\n %s\n %s\n %s\n %s\n' 'Task' 'Time' 'Vox' 'Slices' 'TR_s' 'Vols' 'TE_ms' 'Acc' 'maxFD' 'meanFD' 'maxAbs' 'FD_0.2' 'v_tSNR' 's_tSNR' 'meanBOLD' 'stdBOLD' | paste -sd ',' > $QCDIR/$projectnm/sub-${SUB}/ses-${SESS}/sub-${SUB}_ses-${SESS}_qcvals.csv

for j in `ls $QCDIR/$projectnm/sub-${SUB}/ses-${SESS}/task-*/sub-*_ses-*_task-*_acq-*_bold_qcvals.csv`
do
cat $j | tail -1 | paste -sd ',' >> $QCDIR/$projectnm/sub-${SUB}/ses-${SESS}/sub-${SUB}_ses-${SESS}_qcvals.csv
done

done
