#!/bin/bash
#SBATCH --account=b1134                	# Our account/allocation
#SBATCH --partition=buyin      		# 'Buyin' submits to our node qhimem0018
#SBATCH --time=02:00:00             	# Walltime/duration of the job
#SBATCH --mem=80GB               	# Memory per node in GB. Also see --mem-per-cpu
#SBATCH --output=/projects/b1134/processed/boldqc/logs/boldqc_run_%a_%A.out
#SBATCH --error=/projects/b1134/processed/boldqc/logs/boldqc_run_%a_%A.err
#SBATCH --job-name="boldqc_run"       	# Name of job

# Braga Lab BOLD QC Run Pipeline
# Created by R. Braga & A. Holubecki on November 2020
# Adapted by M. Lakshman & N. Anderson for Optimal Combination on October 2022

# Usage:
# boldqc_run_oc.sh
# e.g. sh /projects/b1134/tools/boldqc/boldqc_run_oc.sh /projects/b1134/raw/bids/SeqDev/sub-fMRIPILOT1110/ses-fMRIPILOT1110/func/sub-fMRIPILOT1110_ses-fMRIPILOT1110_task-REST01_acq-CBS1p5_bold.nii.gz 4

SCAN=$1
n=$2
ech=$3
vols_match=$4

module load fsl

module load ImageMagick/7.0.4

module load ghostscript/9.19

module load jq

filename=$(basename $SCAN '.nii.gz')

projectnm=$(echo $SCAN | cut -d'/' -f6)
SUB=$(echo $filename | awk -F 'sub-' '{print $2}' | cut -d'_' -f1)
SESS=$(echo $filename | awk -F 'ses-' '{print $2}' | cut -d'_' -f1)
task=$(echo $filename | awk -F 'task-' '{print $2}' | cut -d'_' -f1)
acq=$(echo $filename | awk -F 'acq-' '{print $2}' | cut -d'_' -f1)

# Set directories:

DATAPATH=$(dirname $SCAN)
OUTPATH=/projects/b1134/processed/boldqc/$projectnm/sub-${SUB}/ses-${SESS}/task-$task
TMPDIR=$OUTPATH/tmp_oc

mkdir -p $TMPDIR
cd $TMPDIR

#Check if file exists
if [[ ! -e $SCAN ]]; then
	echo "File not found: $SCAN"
	#exit
fi

### SKIPPING FIRST n VOLUMES
totpts=$(fslinfo $SCAN | awk '{print $2}' | awk 'FNR == 5 {print}')
echo "Number of volumes: $totpts" #make sure this is equal to the number of frames in the scan
numpts=$(($totpts-$n))

for k in `seq 1 1 $ech`;
do 
	filename_ech=sub-${SUB}_ses-${SESS}_task-${task}_acq-${acq}_echo-${k}_bold

	echo "Skipping first $n volumes"
	fslroi ${DATAPATH}/${filename_ech} $TMPDIR/${filename_ech}_skip $n $numpts

	#cp $SCAN $TMPDIR/${filename}_skip.nii.gz #need to do this and comment out above command for very short phantoms.

	### PERFORMING MOTION CORRECTION
	echo 'Performing motion correction'
	mcflirt -in $TMPDIR/${filename_ech}_skip -out $TMPDIR/${filename_ech}_skip_mc -refvol 0 -plots -rmsrel -rmsabs
done

sh /projects/b1134/tools/boldqc/opt_comb_calc.sh $TMPDIR $projectnm $SUB $SESS $task $acq $ech

# CREATING MOTION PLOTS
echo 'Creating motion plots'
rot="0.020"
ymin_rot=$(bc<<<"0-$rot")
ymax_rot=$(bc<<<"0+$rot")

fsl_tsplot -i $TMPDIR/${filename}_skip_mc.par -t 'MCFLIRT estimated rotations (radians)' -u 1 --start=1 --finish=3 --ymin=$ymin_rot --ymax=$ymax_rot -w 651 -h 144 -o $TMPDIR/${filename}_skip_mc_rot.png

convert $TMPDIR/${filename}_skip_mc_rot.png -crop 653x166+25+0 $OUTPATH/${filename}_skip_mc_rot.png

trans="1.000"
ymin_trans=$(bc<<<"0-$trans")
ymax_trans=$(bc<<<"0+$trans")

fsl_tsplot -i $TMPDIR/${filename}_skip_mc.par -t 'MCFLIRT estimated translations (mm)' -u 1 --start=4 --finish=6 --ymin=$ymin_trans --ymax=$ymax_trans -w 640 -h 144 -o $TMPDIR/${filename}_skip_mc_trans.png

convert $TMPDIR/${filename}_skip_mc_trans.png -crop 653x167+14+0 $OUTPATH/${filename}_skip_mc_trans.png

fsl_tsplot -i $TMPDIR/${filename}_skip_mc_abs.rms, -t 'MCFLIRT estimated absolute mean displacement (mm)' -u 1 --ymin=0 --ymax=2 -w 635 -h 144 -o $TMPDIR/${filename}_skip_mc_disp_abs.png

convert $TMPDIR/${filename}_skip_mc_disp_abs.png -crop 653x167+10+0 $OUTPATH/${filename}_skip_mc_disp_abs.png

fsl_tsplot -i $TMPDIR/${filename}_skip_mc_rel.rms -t 'MCFLIRT estimated relative mean displacement (mm)' -u 1 --ymin=0 --ymax=1 -w 646 -h 144 -o $TMPDIR/${filename}_skip_mc_disp_rel.png

convert $TMPDIR/${filename}_skip_mc_disp_rel.png -crop 653x167+20+0 $OUTPATH/${filename}_skip_mc_disp_rel.png

filename_oc=sub-${SUB}_ses-${SESS}_task-${task}_acq-${acq}_echo-oc_bold

### MEAN, STD, TSNR
echo 'Calculating mean and std image'
#fslmaths $TMPDIR/${filename}_skip_mc -Tmean $TMPDIR/${filename}_skip_mc_mean
fslmaths $TMPDIR/${filename_oc}_skip_mc -Tstd $TMPDIR/${filename_oc}_skip_mc_std

echo 'Creating tSNR image'
fslmaths $TMPDIR/${filename_oc}_skip_mc_mean -div $TMPDIR/${filename_oc}_skip_mc_std $TMPDIR/${filename_oc}_skip_mc_tsnr

### CALCULATIONS
echo 'Calculating max framewise displacement'
maxfd=$(cat $TMPDIR/${filename}_skip_mc_rel.rms | sort -n | tail -1)
echo "    = $maxfd"

echo 'Calculating mean framewise displacement'
meanfd=$(cat $TMPDIR/${filename}_skip_mc_rel_mean.rms)
echo "    = $meanfd"

echo 'Calculating max motion'
maxabs=$(cat $TMPDIR/${filename}_skip_mc_abs.rms | sort -n | tail -1)
echo "    = $maxabs"

echo 'Calculating FD > 0.2'
fds=$(cat $TMPDIR/${filename}_skip_mc_rel.rms | sort -r)
count=0
limit=0.2
for v in $fds
do
result=$(bc -l <<< $v)
if (( $(echo "$result > $limit" |bc -l) )); then
count=$(($count+1))
else
break
fi
done
numovp2=$count
echo "    = $numovp2"

echo 'Calculating voxel tSNR'
voxtsnr=$(fslstats $TMPDIR/${filename_oc}_skip_mc_tsnr -m)
echo "    = $voxtsnr"

echo 'Calculating mean BOLD'
boldmn=$(fslstats $TMPDIR/${filename_oc}_skip_mc_mean -m)
echo "    = $boldmn"

echo 'Calculating mean STD BOLD'
boldstd=$(fslstats $TMPDIR/${filename_oc}_skip_mc_std -m)
echo "    = $boldstd"

bet $TMPDIR/${filename_oc}_skip_mc_mean $TMPDIR/${filename_oc}_skip_mc_mean_brain -m
#echo 'Calculating in-brain tSNR (similar to slice-based tSNR)'
#slsnr=$(fslstats  $TMPDIR/${filename_oc}_skip_mc_tsnr -k $TMPDIR/${filename_oc}_skip_mc_mean_brain_mask -m)
#echo "    = $slsnr"

echo 'Calculating slice-based tSNR'
num_vols=$(fslinfo $TMPDIR/${filename_oc}_skip_mc | awk '{print $2}' | awk 'FNR == 5 {print}')
num_slices=$(fslinfo $TMPDIR/${filename_oc}_skip_mc | awk '{print $2}' | awk 'FNR == 4 {print}')
tmpname=$(echo $RANDOM | md5sum | head -c 10)
fslsplit $TMPDIR/${filename_oc}_skip_mc $tmpname
for (( c=1; c<=$num_vols; c++ ))
do
	vol_num=$(($c-1))
	vol_name=`printf %04d $vol_num`
	bet $TMPDIR/${tmpname}${vol_name} $TMPDIR/${tmpname}${vol_name}_brain -m
	fslmaths $TMPDIR/${tmpname}${vol_name} -mul $TMPDIR/${tmpname}${vol_name}_brain_mask $TMPDIR/${tmpname}${vol_name}_masked
	fslslice $TMPDIR/${tmpname}${vol_name}_masked
done

slice_array=()
for (( c=1; c<=$num_slices; c++ ))
do
	slice_num=$(($c-1))
	slice_name=`printf %04d $slice_num`
	vol_array=()
	for (( d=1; d<=$num_slices; d++ ))
	do
		vol_num=$(($d-1))
		vol_name=`printf %04d $vol_num`
		
		volslice=$TMPDIR/${tmpname}${vol_name}_masked_slice_${slice_name}
		volslice_mean=$(fslstats $volslice -m)
		vol_array+=("$volslice_mean")
	done

	sum=0
	total=0
	for i in "${vol_array[@]}"
	do
		sum=$(echo "$sum+$i" | bc)
		total=$(echo "$total+1" | bc)
	done

	mean=$(echo "scale=4; $sum/$total" | bc)

	sumdev=0
	for i in "${vol_array[@]}"
	do
		dev=$(echo "scale=4; $i-$mean" | bc)
		devsq=$(echo "scale=4; $dev^2" | bc)
		sumdev=$(echo "scale=4; $sumdev+$devsq" | bc)
	done
	stdevsq=$(echo "scale=4; $sumdev/$total" | bc)
	stdev=$(echo "$stdevsq" | awk '{print sqrt($1)}')
	tsnr=$(echo "scale=4; $mean/$stdev" | bc)
	slice_array+=($tsnr)
done

tsnr_sum=0
tsnr_total=0
for i in "${slice_array[@]}"
do
	tsnr_sum=$(echo "scale=4; $tsnr_sum+$i" | bc)
	tsnr_total=$(echo "scale=4; $tsnr_total+1" | bc)

done
slsnr=$(echo "scale=1; $tsnr_sum/$tsnr_total" | bc)
echo "    = $slsnr"

rm $TMPDIR/${tmpname}*

# Get values from .json (header)
echo 'Preparing QC table'

# Run name 
runnm=$task
echo "   Task = $runnm"

# Acquisition time (hh:mm)
actime=($(jq -r '.AcquisitionTime' $DATAPATH/${filename}.json | cut -d":" -f1,2))
echo "   Acquisition time = $actime"

# Voxel dimensions
voxx=$(fslinfo $DATAPATH/$filename | awk 'NR==7 {print $2}')
voxx=$(printf '%.1f' $voxx)
voxy=$(fslinfo $DATAPATH/$filename | awk 'NR==8 {print $2}')
voxy=$(printf '%.1f' $voxy)
voxz=$(fslinfo $DATAPATH/$filename | awk 'NR==9 {print $2}')
voxz=$(printf '%.1f' $voxz)

if [[ $voxx == $voxy && $voxy == $voxz ]]; then
voxsize="${voxx}_iso"
else 
voxsize=${voxx}x${voxy}x${voxz}
fi 

echo "   Voxel Dimensions = $voxsize"

# Number of slices
zdim=$(fslinfo $DATAPATH/$filename | awk 'NR==4 {print $2}')
echo "   Number of Slices = $zdim"

# Calculate weighted tSNR
fslmaths $TMPDIR/${filename_oc}_skip_mc_tsnr -mas $TMPDIR/${filename_oc}_skip_mc_mean_brain_mask $TMPDIR/${filename_oc}_skip_mc_tsnr_brain
volvoxs=$(fslstats $TMPDIR/${filename_oc}_skip_mc_tsnr_brain -V | cut -d" " -f1)

mkdir slices

for i in `seq 1 1 $zdim`
do
echo $i
cmd="fslroi $TMPDIR/${filename_oc}_skip_mc_tsnr_brain slices/slice_$i 0 -1 0 -1 $i 1"
echo $cmd; $cmd

sltsnr=$(fslstats slices/slice_$i -M) 
echo $sltsnr >> slices/slice_tsnrs.txt
slvoxs=$(fslstats slices/slice_$i -V | cut -d" " -f1)
echo $slvoxs >> slices/slice_vol.txt

#Weighted tSNR: multiply masked tSNR per slice by number of voxels in that slice
wtsnr=$(echo "$sltsnr * $slvoxs" |bc -l)
echo $wtsnr >> slices/slice_wtsnrs.txt
done

#Sum weighted tSNR values from all slices
wtsnrsum=$(paste -sd+ slices/slice_wtsnrs.txt | bc)

#Divide by total number of voxels
wsltsnr=$(echo "$wtsnrsum / $volvoxs" |bc -l)

# TR (s)
TR=($(jq -r '.RepetitionTime' $DATAPATH/${filename}.json))

# Number of volumes is $totpts variable from above
vols=$(fslinfo $DATAPATH/$filename | awk 'NR==5 {print $2}')

# TE (ms)
TE=$(jq -r '.EchoTime' $DATAPATH/${filename}.json | awk 'NF{print $1*1000}' OFMT="%.1f" )

# Acceleration factor (SMS.in-plane)
SMS=$(jq -r '.MultibandAccelerationFactor' $DATAPATH/${filename}.json)
if [[ $SMS = 'null' ]]; then
echo 'Multiband field is empty'
SMS=0
fi

inplane=$(jq -r '.ParallelReductionFactorInPlane' $DATAPATH/${filename}.json )
if [[ $inplane = 'null' ]]; then
echo 'In-plane field is empty'
inplane=0
fi

acc="${SMS}-${inplane}"
echo "    Acceleration (SMS-inplane) = $acc"

#Print values to csv
printf '%s\n %s\n %s\n %s\n %s\n %s\n %s\n %s\n %s\n %s\n %s\n %s\n %s\n %s\n %s\n %s\n' 'Task' 'Time' 'Vox' 'Slices' 'TR_s' 'Vols' 'TE_ms' 'Acc' 'maxFD' 'meanFD' 'maxAbs' 'FD_0.2' 'v_tSNR' 's_tSNR' 'meanBOLD' 'stdBOLD' | paste -sd ',' > $OUTPATH/${filename_oc}_qcvals.csv
printf '%s\n %s\n %s\n %s\n %.2f, %.0f, %.1f, %s\n %.3f, %.3f, %.3f, %s\n %.1f, %.1f, %.0f, %.0f' $runnm $actime $voxsize $zdim $TR $vols $TE $acc $maxfd $meanfd $maxabs $numovp2 $voxtsnr $slsnr $boldmn $boldstd | paste -sd ',' >> $OUTPATH/${filename_oc}_qcvals.csv
cat $OUTPATH/${filename_oc}_qcvals.csv

# SLICER IMAGES
sh /projects/b1134/tools/slicer_imgs/slicer_boldqc.sh $TMPDIR/${filename_oc}_skip_mc_mean.nii.gz $OUTPATH ${filename_oc}_skip_mc_mean
sh /projects/b1134/tools/slicer_imgs/slicer_boldqc.sh $TMPDIR/${filename_oc}_skip_mc_std.nii.gz $OUTPATH ${filename_oc}_skip_mc_std
sh /projects/b1134/tools/slicer_imgs/slicer_boldqc.sh $TMPDIR/${filename_oc}_skip_mc_tsnr.nii.gz $OUTPATH ${filename_oc}_skip_mc_tsnr
#fi

# GENERATE REPORT
 
module load fftw/3.3.3-gcc

module load R/3.6.0

Rscript /projects/b1134/tools/boldqc/boldqc_report/boldqc_report_run_oc.R "$projectnm" "$SUB" "$SESS" "$task" "$acq" "$filename" "$filename_oc" "$vols_match"
rm $OUTPATH/Rplots.pdf

# Cleanup
#rm -r $TMPDIR
rm $OUTPATH/${filename_oc}*.png

### END QC
