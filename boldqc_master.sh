
# Usage:
# sh /projects/b1134/tools/boldqc/boldqc_master.sh

# Run boldqc for all bold runs in raw/bids directory - by R. Braga 11/2020

qcv=boldqc_201120.sh

BIDSDIR=/projects/b1134/raw/bids

QCDIR=/projects/b1134/processed/boldqc


echo "-----"; echo "Running boldqc version: $qcv";echo "-----"

echo "Checking bids directory for new bold runs..."
echo "Bids directory: $BIDSDIR"

echo "-----"; echo "Will save QC output to: $QCDIR"; echo "-----"

echo "Project  -  Subject  -  Session  -  Task"


for i in `ls $BIDSDIR/*/sub-*/ses-*/func/*_bold.nii.gz`
do
#echo "Running QC for file: $i"
filename=$(basename $i '.nii.gz')

projectnm=$(echo $i | cut -d'/' -f6)
SUB=$(echo $filename | awk -F 'sub-' '{print $2}' | cut -d'_' -f1)
SESS=$(echo $filename | awk -F 'ses-' '{print $2}' | cut -d'_' -f1)
task=$(echo $filename | awk -F 'task-' '{print $2}' | cut -d'_' -f1)
#acq=$(echo $filename | awk -F 'acq-' '{print $2}' | cut -d'_' -f1)

echo "$projectnm $SUB $SESS $task"
DATAPATH=$BIDSDIR/$projectnm/sub-$SUB/ses-$SESS/func
OUTDIR=$QCDIR/$projectnm/sub-$SUB/ses-$SESS/task-$task

outfile=${filename}_skip_mc_mean_sag.png

#Skip n vols based on TR
tr=$(fslinfo $i | awk '{print $2}' | awk 'FNR == 10 {print}')
numskip=$(echo "( 12/$tr ) /1" | bc) 

if [ ! -s $OUTDIR/$outfile ]; then 

#ls $DATAPATH/${filename}.nii.gz
#ls $OUTDIR/$outfile

cmd="sh /projects/b1134/tools/boldqc/$qcv $i $numskip"
echo $cmd
#$cmd

else

echo "----- Skipping"

fi

done

# Creat CSV for entire session

for i in `dir $QCDIR/*/sub-*`
do
echo "Merging QC run reports for $i into session report"

projectnm=$(realpath $i | awk -F 'boldqc/' '{print $2}'  | cut -d'/' -f1)
SUB=$(realpath $i | awk -F 'sub-' '{print $2}' | cut -d'/' -f1)
SESS=$(realpath $i | awk -F 'ses-' '{print $2}' | cut -d'/' -f1)

printf '%s\n %s\n %s\n %s\n %s\n %s\n %s\n %s\n %s\n %s\n %s\n %s\n %s\n %s\n %s\n %s\n' 'Task' 'Time' 'Vox' 'Slices' 'TR_s' 'Vols' 'TE_ms' 'Acc' 'maxFD' 'meanFD' 'maxAbs' 'FD_0.2' 'v_tSNR' 's_tSNR' 'meanBOLD' 'stdBOLD' | paste -sd ',' > $QCDIR/$projectnm/sub-${SUB}/ses-${SESS}/sub-${SUB}_ses-${SESS}_qcvals.csv

for j in `ls $QCDIR/$projectnm/sub-${SUB}/ses-${SESS}/task-*/sub-*_ses-*_task-*_acq-*_bold_qcvals.csv`
do
cat $j | tail -1 | paste -sd ',' >> $QCDIR/$projectnm/sub-${SUB}/ses-${SESS}/sub-${SUB}_ses-${SESS}_qcvals.csv
done

done

# Create PDF per session

# Create Slicer images

# CBS 2p4 mean BOLD
#sh /projects/b1134/tools/slicer_imgs/slicer_boldqc_CBS2p4.sh /projects/b1134/processed/boldqc/SeqDev/sub-fMRIPILOT1030/ses-fMRIPILOT1030/tmp/sub-fMRIPILOT1030_ses-fMRIPILOT1030_task-REST02_acq-CBS2p4_bold_skip_mc_mean.nii.gz /projects/b1134/processed/boldqc/SeqDev/sub-fMRIPILOT1030/ses-fMRIPILOT1030/task-REST02 sub-fMRIPILOT1030_ses-fMRIPILOT1030_task-REST02_acq-CBS2p4_meanBOLD

