#!/bin/bash

#compile qc report csv
# QY 10/2/2021
# usage:
# boldqc_cplreport.sh subjectid

project=
sub=
SUBJDIR=/projects/b1134/processed/boldqc/$project/sub-$sub/
cd $SUBJDIR

echo "Sub, Sess, Run, Task, Time, Vox, Slices, TR_s, Vols, TE_ms, Acc, maxFD, meanFD, maxAbs, FD_0.2, v_tSNR, s_tSNR, meanBOLD, stdBOLD" > compiled_qcval.csv

for i in `ls $SUBJDIR/*/*/*_bold_qcvals.csv`
do
	filename=$(basename $i '.csv')
	SUB=$(echo $filename | awk -F 'sub-' '{print $2}' | cut -d'_' -f1)
	SESS=$(echo $filename | awk -F 'ses-' '{print $2}' | cut -d'_' -f1)
	RUN=$(echo $filename | awk -F 'run-' '{print $2}' | cut -d'_' -f1)
	echo $SUB, $SESS, $RUN, $(awk '(NR>1)' $i) >> compiled_qcval.csv
done


