#!/bin/bash

#compile qc report csv for Multi-Echo data
# ML 11/3/2021
# usage:
# boldqc_cplreport_ME.sh subjectid

project=BNI
sub=YKBYHS
ses=2201193TAR00029
SUBJDIR=/projects/b1134/processed/boldqc/$project/sub-$sub/ses-$ses
cd $SUBJDIR

#set headers for final CSV file
echo "Sub, Sess, Task, Time, Vox, Slices, TR_s, Vols, TE_ms, Acc, maxFD, meanFD, maxAbs, FD_0.2, meanBOLD, stdBOLD, vtSNR, stSNR" > compiled_qcval.csv

#read the second line of each Echo-1 CSV and export to new CSV
for i in `ls $SUBJDIR/*/*_echo-1_bold_qcvals.csv`
do
	filename=$(basename $i '.csv')
	SUB=$(echo $filename | awk -F 'sub-' '{print $2}' | cut -d'_' -f1)
	SESS=$(echo $filename | awk -F 'ses-' '{print $2}' | cut -d'_' -f1)
	echo $SUB, $SESS, $(awk '(NR>1)' $i) >> full_qcval.csv
done

#Delete the vtSNR and stSNR columns from new CSV
#Reformat CSV to columns
#Delete blank spaces in CSV
echo $(cut -d, -f15-16 --complement full_qcval.csv) > full_qcval.csv
sed "s/$sub/\n&/g" full_qcval.csv >> compiled_qcval.csv
sed -i ' /^$/d' compiled_qcval.csv

#Read the second line of each Echo-2 CSV and export to new CSV
for j in `ls $SUBJDIR/*/*_echo-2_bold_qcvals.csv`
do 
	filename=$(basename $j '.csv')
	SUB=$(echo $filename | awk -F 'sub-' '{print $2}' | cut -d'_' -f1)
	SESS=$(echo $filename | awk -F 'ses-' '{print $2}' | cut -d'_' -f1)
	echo $SUB, $SESS, $(awk '(NR>1)' $j) >> echo2_qcval.csv
done

#Extract vtSNR and stSNR columns from Echo-2 CSV
awk -F "\"*,\"*" '{print $15,",",$16}' echo2_qcval.csv >> echo2_1516_qcval.csv
#get rid of unnecessary spaces
sed -i.bak -E 's/(^|,)[[:blank:]]+/\1/g; s/[[:blank:]]+(,|$)/\1/g' echo2_1516_qcval.csv
#blank line at the beginning of echo2 csv
sed '1 i \
' echo2_1516_qcval.csv >> echo2_final_qcval.csv

#Merge compiled_qcval (Echo-1 data) and Echo-2 data
paste -d, compiled_qcval.csv echo2_final_qcval.csv >> compiled_[$ses]_qcval.csv

#Remove all intermediary CSVs
rm full_qcval.csv
rm echo2_qcval.csv
rm echo2_1516_qcval.csv
rm echo2_final_qcval.csv
rm echo2_1516_qcval.csv.bak
rm compiled_qcval.csv



