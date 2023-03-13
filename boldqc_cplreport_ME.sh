#!/bin/bash

#Compile qc report csv for Multi-Echo data
# Created by M. Lakshman on 11/3/2021 -- edited on 2/18/22
# usage:
# sh boldqc_cplreport_ME.sh

#projectnm=$1
#SUB=$2
#SESS=$3
#SUBJDIR=/projects/b1134/processed/boldqc/$projectnm/sub-$SUB/ses-$SESS
#cd $SUBJDIR

QCDIR=/projects/b1134/processed/boldqc
cd $QCDIR

for a in $QCDIR/*/sub-*/*
do
	echo $a/compiled_${SESS}_qcval.csv

	for i in `ls $a/*/*_echo-1_bold_qcvals.csv`
	do
		filename=$(basename $i '.csv')
		SESS=$(echo $filename | awk -F 'ses-' '{print $2}' | cut -d'_' -f1)
	done

echo $a/compiled_${SESS}_qcval.csv

	if [ -f $a/compiled_${SESS}_qcval.csv ]; then 
	echo "skipping"
	continue
	fi 

	echo $a

	#set headers for compiled CSV file
	echo "Sub, Sess, Task, maxAbs, maxFD, meanFD, FD_0.2, stSNR, vtSNR, Vox, TR_s, Vols, TE_ms, meanBOLD, stdBOLD" > $a/compiled.csv

	#read the second line of each Echo-1 CSV and export to new CSV
	for i in `ls $a/*/*_echo-1_bold_qcvals.csv`
	do
		filename=$(basename $i '.csv')
		SUB=$(echo $filename | awk -F 'sub-' '{print $2}' | cut -d'_' -f1)
		SESS=$(echo $filename | awk -F 'ses-' '{print $2}' | cut -d'_' -f1)
		echo $SUB, $SESS, $(awk '(NR>1)' $i) >> $a/echo1_qcval.csv
	done

	#Extract first columns from Echo-1 CSV
	awk -F "\"*,\"*" '{print $1,",",$2,",",$3,",",$4,",",$5,",",$7,",",$8,",",$9,",",$11,",",$12,",",$13,",",$14,",",$17,",",$18}' $a/echo1_qcval.csv >> $a/echo1_partial_qcval.csv

	#Read the second line of each Echo-2 CSV and export to new CSV
	for j in `ls $a/*/*_echo-2_bold_qcvals.csv`
	do 
		filename=$(basename $j '.csv')
		SUB=$(echo $filename | awk -F 'sub-' '{print $2}' | cut -d'_' -f1)
		SESS=$(echo $filename | awk -F 'ses-' '{print $2}' | cut -d'_' -f1)
		echo $SUB, $SESS, $(awk '(NR>1)' $j) >> $a/echo2_qcval.csv
	done

	#Extract vtSNR and stSNR columns from Echo-2 CSV
	awk -F "\"*,\"*" '{print $15,",",$16}' $a/echo2_qcval.csv >> $a/echo2_partial_qcval.csv

	#Paste Echo2 CSV values next to Echo1 CSV
	paste -d ',' $a/echo1_partial_qcval.csv $a/echo2_partial_qcval.csv >> $a/int_compiled_qcval.csv

	#Reorder columns to look like the QC_MRI Excel Spreadsheets
	awk -F, '{print $1,$2,$3,$11,$9,$10,$12,$16,$15,$5,$6,$7,$8,$13,$14}' OFS=, "$a/int_compiled_qcval.csv" >> $a/reorg_qcval.csv
	echo $a

	#migrate contents of reorg to the compiled spreadsheet with headers
	sed '1 s/^/\n/' $a/reorg_qcval.csv >> $a/compiled.csv

	#delete unnecessary spaces
        sed -i " /^$/d" $a/compiled.csv

	#create blank columns for free response on Excel
	awk -F, '{$3=FS$3; $4=FS$4; $10=FS$10; $10=FS$10}1' OFS=, $a/compiled.csv >> $a/compiled_${SESS}_qcval.csv

	#Remove all intermediary CSVs
	rm $a/compiled.csv
	rm $a/echo1_qcval.csv
	rm $a/echo1_partial_qcval.csv
	rm $a/echo2_qcval.csv
	rm $a/echo2_partial_qcval.csv
	rm $a/int_compiled_qcval.csv
	rm $a/reorg_qcval.csv

done
 
