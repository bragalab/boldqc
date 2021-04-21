#!/bin/bash
#SBATCH --account=b1134                	# Our account/allocation
#SBATCH --partition=buyin      		# 'Buyin' submits to our node qhimem0018
#SBATCH --time=04:00:00             	# Walltime/duration of the job (6 hours for 16 tasks)
#SBATCH --mem=40GB               	# Memory per node in GB. Also see --mem-per-cpu
#SBATCH --output=/projects/b1134/processed/boldqc/logs/boldqc_master_%a_%A.out
#SBATCH --error=/projects/b1134/processed/boldqc/logs/boldqc_master_%a_%A.err
#SBATCH --job-name="boldqc_master"       	# Name of job

# Braga Lab BOLD QC Master Pipeline
# Created by R. Braga on November 2020

# Usage:
# sh /projects/b1134/tools/boldqc/boldqc_master.sh
# Run boldqc for all bold runs in raw/bids directory

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

outfile=${filename}_qcreport.pdf

if [ ! -s $OUTDIR/$outfile ]; then 

#Skip n vols based on TR (12 seconds)
tr=$(fslinfo $i | awk '{print $2}' | awk 'FNR == 10 {print}')
numskip=$(echo "( 12/$tr ) /1" | bc) 


ls $DATAPATH/${filename}.nii.gz
ls $OUTDIR/$outfile

cmd="sbatch /projects/b1134/tools/boldqc/$qcv $i $numskip"
echo $cmd

jid=$($cmd | cut -d ' ' -f4)

else

echo "----- Skipping"

fi

done

# Collate QCs into sessions

sbatch --dependency=afterok:${jid} /projects/b1134/tools/boldqc/boldqc_session_201207.sh

