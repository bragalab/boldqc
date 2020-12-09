
# Usage:
# sh /projects/b1134/tools/boldqc/boldqc_master.sh

# Run boldqc for all bold runs in raw/bids directory - by R. Braga 11/2020

qcv=boldqc_run_201120.sh

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

#sh /projects/b1134/boldqc/boldqc_session_201207.sh

# Create PDF per session

