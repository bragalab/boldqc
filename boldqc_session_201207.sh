#!/bin/bash
#SBATCH --account=b1134                	# Our account/allocation
#SBATCH --partition=buyin      		# 'Buyin' submits to our node qhimem0018
#SBATCH --time=00:20:00             	# Walltime/duration of the job
#SBATCH --mem=40GB               	# Memory per node in GB. Also see --mem-per-cpu
#SBATCH --output=/projects/b1134/processed/boldqc/logs/boldqc_session_%a_%A.out
#SBATCH --error=/projects/b1134/processed/boldqc/logs/boldqc_session_%a_%A.err
#SBATCH --job-name="boldqc_session"       	# Name of job

# Braga Lab BOLD QC Session Pipeline
# Created by A. Holubecki on December 2020

# Usage:
# boldqc_session_201207.sh
# e.g. sh /projects/b1134/tools/boldqc/boldqc_session_201207.sh 

# Create CSV for entire session

QCDIR=/projects/b1134/processed/boldqc

for i in $QCDIR/*/sub-*/*
do

projectnm=$(realpath $i | awk -F 'boldqc/' '{print $2}'  | cut -d'/' -f1)
SUB=$(realpath $i | awk -F 'sub-' '{print $2}' | cut -d'/' -f1)
SESS=$(realpath $i | awk -F 'ses-' '{print $2}' | cut -d'/' -f1)
echo "Merging QC run CSVs for session $SESS into session CSV"

printf '%s\n %s\n %s\n %s\n %s\n %s\n %s\n %s\n %s\n %s\n %s\n %s\n %s\n %s\n %s\n %s\n' 'Task' 'Time' 'Vox' 'Slices' 'TR_s' 'Vols' 'TE_ms' 'Acc' 'maxFD' 'meanFD' 'maxAbs' 'FD_0.2' 'v_tSNR' 's_tSNR' 'meanBOLD' 'stdBOLD' | paste -sd ',' > $QCDIR/$projectnm/sub-${SUB}/ses-${SESS}/sub-${SUB}_ses-${SESS}_qcvals.csv

for j in `ls $QCDIR/$projectnm/sub-${SUB}/ses-${SESS}/task-*/sub-*_ses-*_task-*_acq-*_bold_qcvals.csv`
do
cat $j | tail -1 | paste -sd ',' >> $QCDIR/$projectnm/sub-${SUB}/ses-${SESS}/sub-${SUB}_ses-${SESS}_qcvals.csv
done

#echo "Merging QC run PDFs for session $SESS into session PDF"

module load fftw/3.3.3-gcc

module load R/3.6.0

Rscript /projects/b1134/tools/boldqc/boldqc_report/boldqc_report_session_20201130.R "$projectnm" "$SUB" "$SESS"
rm $i/Rplots.pdf

done


