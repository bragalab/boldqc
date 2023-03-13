#!/bin/bash
#SBATCH --account=b1134                	# Our account/allocation
#SBATCH --partition=buyin      		# 'Buyin' submits to our node qhimem0018
#SBATCH --time=01:00:00             	# Walltime/duration of the job (6 hours for 16 tasks)
#SBATCH --mem=40GB               	# Memory per node in GB. Also see --mem-per-cpu
#SBATCH --output=/projects/b1134/processed/boldqc/logs/boldqc_master_%a_%A.out
#SBATCH --error=/projects/b1134/processed/boldqc/logs/boldqc_master_%a_%A.err
#SBATCH --job-name="boldqc_master"       	# Name of job

# Braga Lab BOLD QC Master Pipeline
# Created by R. Braga on November 2020
# Adapted by M. Lakshman & N. Anderson for Optimal Combination on October 2022

# Usage:
# sh /projects/b1134/tools/boldqc/boldqc_master.sh
# Run boldqc for all bold runs in raw/bids directory

qcv1=boldqc_run_oc.sh
qcv2=boldqc_run_230201.sh

BIDSDIR=/projects/b1134/raw/bids

QCDIR=/projects/b1134/processed/boldqc


echo "-----"; echo "Running boldqc version: $qcv";echo "-----"

echo "Checking bids directory for new bold runs..."
echo "Bids directory: $BIDSDIR"

echo "-----"; echo "Will save QC output to: $QCDIR"; echo "-----"

echo "Project  -  Subject  -  Session  -  Task"


#for i in `ls $BIDSDIR/*/sub-*/ses-*/func/*_bold.nii.gz 2> /dev/null`
for i in `ls $BIDSDIR/DBNO/sub-*/ses-*/func/*_bold.nii.gz 2> /dev/null`
do
	#echo "Running QC for file: $i"
	filename=$(basename $i '.nii.gz')

	projectnm=$(echo $i | cut -d'/' -f6)
	SUB=$(echo $filename | awk -F 'sub-' '{print $2}' | cut -d'_' -f1)
	SESS=$(echo $filename | awk -F 'ses-' '{print $2}' | cut -d'_' -f1)
	task=$(echo $filename | awk -F 'task-' '{print $2}' | cut -d'_' -f1)
	acq=$(echo $filename | awk -F 'acq-' '{print $2}' | cut -d'_' -f1)

	DATAPATH=$BIDSDIR/$projectnm/sub-$SUB/ses-$SESS/func
	OUTDIR=$QCDIR/$projectnm/sub-$SUB/ses-$SESS/task-$task

	# Get the number of volumes this run SHOULD have
	volcounts=/projects/b1134/tools/boldqc/volume_counts.txt
	taskname=${task//[0-9]/}

	while IFS=, read -r PROJECT TASK VOLCOUNT
	do
		if [ $projectnm == $PROJECT ] && [ $taskname == $TASK ] ; then
			this_volcount=$VOLCOUNT
		fi
	done < $volcounts

	if [ -z $this_volcount ];
	then
		echo "WARNING: You haven't added $projectnm $taskname's total frame count to:"
		echo "/projects/b1134/tools/boldqc/volume_counts.txt"
		echo "If the number of volumes in your file is incorrect, it won't be noted on the QC PDF."
		echo ""
		vols_match=TRUE
	else
		totpts=$(fslinfo $i | awk '{print $2}' | awk 'FNR == 5 {print}')
		if [ "$this_volcount" = "$totpts" ]; then
			vols_match=TRUE
		else
			vols_match=FALSE
			if !(echo $filename | grep -Eq "^.*echo.*$"); then
				echo "WARNING: Volume counts are NOT correct for $projectnm $SUB $SESS $task"
				echo ""
			else
				echo_num=$(echo $filename | awk -F 'echo-' '{print $2}' | cut -d'_' -f1)
				echo "WARNING: Volume counts are NOT correct for $projectnm $SUB $SESS $task echo $echo_num"
				echo ""
			fi
		fi
	fi

	if (echo $filename | grep -Eq "^.*echo-1_bold.*$"); then 
		print_header=1
		header=$(echo "$projectnm $SUB $SESS $task")

		outfile=sub-${SUB}_ses-${SESS}_task-${task}_acq-${acq}_echo-oc_bold_qcreport.pdf

		if [ ! -s $OUTDIR/$outfile ]; then 
			echo $header
			print_header=0
			echo "----- Opt-comb"

			#Skip n vols based on TR (12 seconds)
			tr=$(fslinfo $i | awk '{print $2}' | awk 'FNR == 10 {print}')
			#numskip=$(echo "( 12/$tr ) /1" | bc)
			numskip=`printf %.0f $(echo "( 12/$tr ) /1" | bc -l)`
			#numskip=0 

			#echo $DATAPATH/${filename}.nii.gz
			#echo $OUTDIR/$outfile

			array_oc=()

			for j in `ls $DATAPATH 2> /dev/null`
			do

				filename_oc=$(basename $j '.nii.gz')

				task_oc=$(echo $filename_oc | awk -F 'task-' '{print $2}' | cut -d'_' -f1)

				if [ $task = $task_oc ] && (echo $j | grep -Eq "^.*_bold\.nii\.gz$"); then

					array_oc+=($j)

				fi
			done

			ech=${#array_oc[@]}

			#cmd="sbatch /projects/b1134/tools/boldqc/$qcv $i $numskip"
			cmd="sbatch /projects/b1134/tools/boldqc/$qcv1 $i $numskip $ech $vols_match"

			#echo $cmd

			jid=$($cmd | cut -d ' ' -f4)

			#echo $ech

		fi
	fi

	outfile=${filename}_qcreport.pdf

	if [ ! -s $OUTDIR/$outfile ]; then 
		if !(echo $filename | grep -Eq "^.*echo.*$"); then
			echo "$projectnm $SUB $SESS $task"
			echo "----- Single echo"
		else
			if [ "$print_header" = "1" ]; then
				echo $header
				print_header=0
			fi
			echo_num=$(echo $filename | awk -F 'echo-' '{print $2}' | cut -d'_' -f1)
			echo "----- Echo $echo_num"
		fi

		#Skip n vols based on TR (12 seconds)
		tr=$(fslinfo $i | awk '{print $2}' | awk 'FNR == 10 {print}')
		#numskip=$(echo "( 12/$tr ) /1" | bc)
		numskip=`printf %.0f $(echo "( 12/$tr ) /1" | bc -l)`
		#numskip=0 


		#ls $DATAPATH/${filename}.nii.gz
		#ls $OUTDIR/$outfile

		#cmd="sbatch /projects/b1134/tools/boldqc/$qcv $i $numskip"
		cmd="sbatch /projects/b1134/tools/boldqc/$qcv2 $i $numskip $vols_match"
		#echo $cmd

		jid=$($cmd | cut -d ' ' -f4)

	fi 
done

# Collate QCs into sessions

#sbatch --dependency=afterok:${jid} /projects/b1134/tools/boldqc/boldqc_session_201207.sh
echo "Check status of jobs using sacct"
echo "Once they are done, submit the following job:"
echo "sh /projects/b1134/tools/boldqc/boldqc_session_201207.sh"

