#!/bin/bash
#SBATCH --account=b1134                	# Our account/allocation
#SBATCH --partition=buyin      		# 'Buyin' submits to our node qhimem0018
#SBATCH --time=00:20:00             	# Walltime/duration of the job
#SBATCH --mem=40GB               	# Memory per node in GB. Also see --mem-per-cpu
#SBATCH --output=/projects/b1134/processed/boldqc/logs/boldqc_oc_%a_%A.out
#SBATCH --error=/projects/b1134/processed/boldqc/logs/boldqc_oc_%a_%A.err
#SBATCH --job-name="boldqc_oc"       	# Name of job

# Braga Lab BOLD QC Optimally Combined Echoes/T2S Pipeline
# Created by M. Lakshman on July 2021

# Usage: 
# boldqc_oc_210713.sh
# e.g. sh /projects/b1134/tools/boldqc/boldqc_oc_210713.sh

# Define directories 

BASEDIR=/projects/b1134
BIDSDIR=$BASEDIR/raw/bids
PROCESSEDDIR=$BASEDIR/processed/boldqc
projectnm=BNI
SUB=KKYNWLTEST

# Extract the correct TE values from respective Rest CSVs

index_of_te_file=0
te_ms=()
previous_echo_number=1

# find all of the CSV files
for te_file in `ls $PROCESSEDDIR/$projectnm/sub-${SUB}/ses-*/*REST01*/*.csv`; do
    # read each lines
    IFS=$',' read -d '' -r -a lines < $te_file

    count=7
    stripped_path_name=${te_file%"_bold_qcvals.csv"}
    echo_number=${stripped_path_name: -1}
    if [ $echo_number -lt $previous_echo_number ]; then
        break
    else
        for i in ${lines[@]}; do
            if [[ $i == *"REST01"* ]]; then
                count=0
            fi

            if [[ $count -eq 6 ]]; then
                te_ms+=($i)
            fi
            count=$((count + 1))
        done;
    fi
    previous_echo_number=$echo_number
done;

# loop over te_ms and make sure that all the right floats are in it
all_te_ms_values=""
for i in ${te_ms[@]}; do
    all_te_ms_values="$all_te_ms_values $i"
done;

# my string will be the X number of floats that needs to be passed to t2smap
echo $mystring 

# this groups echos from however many sessions and RESTS
previous_echo_number=1
commandline="t2smap -d "
for i in `ls /projects/b1134/raw/bids/BNI/sub-${SUB}/ses-*/func/*REST*bold.nii.gz`; do
    stripped_path_name=${i%"_bold.nii.gz"}
    echo_number=${stripped_path_name: -1}
    if [ $echo_number -lt $previous_echo_number ]; then
        commandline+="-e $all_te_ms_values"
        echo $commandline >> "${SUB}_allcommands.sh"
        commandline="t2smap -d $i "
    else
        commandline+="$i "
    fi
    previous_echo_number=$echo_number
done

t2smap -d $i -e $mystring




