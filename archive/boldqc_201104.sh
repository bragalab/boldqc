# Braga Lab QC Pipeline
# Created by Ania Holubecki on September 28th, 2020

# Usage:
# boldqc.sh projectid  subid sessionid scan_name skip_trs
# e.g. boldqc.sh SeqDev fMRIPILOT1030 fMRIPILOT1030 sub-fMRIPILOT1030_ses-fMRIPILOT1030_task-REST_run-02_acq-CBS2p4_bold

projectnm=$1
SUB=$2
SESS=$3
SCAN=$4
n=$5

# Set directories:

DATAPATH=/projects/b1134/raw/bids/$projectnm/sub-${SUB}/ses-${SESS}/func
OUTPATH=/projects/b1134/processed/boldqc/$projectnm/sub-${SUB}/ses-${SESS}
TMPDIR=$OUTPATH/tmp

mkdir -p $TMPDIR
cd $TMPDIR

#Check if file exists
if [[ ! -e $DATAPATH/${SCAN}.nii ]]; then
	echo "File $DATAPATH/${SCAN}.nii not found"
	exit
fi

### SKIPPING FIRST n VOLUMES
totpts=$(fslinfo $DATAPATH/$SCAN | awk '{print $2}' | awk 'FNR == 5 {print}')
echo $totpts #make sure this is equal to the number of frames in the scan
numpts=$(($totpts-$n))

echo 'Skipping first 4 volumes'
fslroi $DATAPATH/${SCAN} $TMPDIR/${SCAN}_skip $n $numpts

### PERFORMING MOTION CORRECTION
echo 'Performing motion correction'
mcflirt -in $TMPDIR/${SCAN}_skip -out $TMPDIR/${SCAN}_skip_mc -refvol 0 -plots -rmsrel -rmsabs -report

# CREATING MOTION PLOTS
rot="0.010"
ymin_rot=$(bc<<<"0-$rot")
ymax_rot=$(bc<<<"0+$rot")

fsl_tsplot -i $TMPDIR/${SCAN}_skip_mc.par -t 'MCFLIRT estimated rotations (radians)' -u 1 --start=1 --finish=3 --ymin=$ymin_rot --ymax=$ymax_rot -a x,y,z -w 640 -h 144 -o $OUTPATH/${SCAN}_skip_mc_rot.png

trans="1"
ymin_trans=$(bc<<<"0-$trans")
ymax_trans=$(bc<<<"0+$trans")

fsl_tsplot -i $TMPDIR/${SCAN}_skip_mc.par -t 'MCFLIRT estimated translations (mm)' -u 1 --start=4 --finish=6 --ymin=$ymin_trans --ymax=$ymax_trans -a x,y,z -w 640 -h 144 -o $OUTPATH/${SCAN}_skip_mc_trans.png

fsl_tsplot -i $TMPDIR/${SCAN}_skip_mc_rel.rms -t 'MCFLIRT estimated relative mean displacement (mm)' -u 1 --ymin=0 --ymax=1 -w 640 -h 144 -o $OUTPATH/${SCAN}_skip_mc_disp_rel.png

fsl_tsplot -i $TMPDIR/${SCAN}_skip_mc_abs.rms, -t 'MCFLIRT estimated absolute mean displacement (mm)' -u 1 --ymin=0 --ymax=1 -w 640 -h 144 -o $OUTPATH/${SCAN}_skip_mc_disp_abs.png

### MEAN, STD, TSNR
echo 'Calculating mean and std image'
fslmaths $TMPDIR/${SCAN}_skip_mc -Tmean $TMPDIR/${SCAN}_skip_mc_mean
fslmaths $TMPDIR/${SCAN}_skip_mc -Tstd $TMPDIR/${SCAN}_skip_mc_std

echo 'Creating tSNR image'
fslmaths $TMPDIR/${SCAN}_skip_mc_mean -div $TMPDIR/${SCAN}_skip_mc_std $TMPDIR/${SCAN}_skip_mc_tsnr

### CALCULATIONS
echo 'Calculating max framewise displacement'
maxfd=$(cat $TMPDIR/${SCAN}_skip_mc_rel.rms | sort -n | tail -1)

echo 'Calculating mean framewise displacement'
meanfd=$(cat $TMPDIR/${SCAN}_skip_mc_rel_mean.rms)

echo 'Calculating max motion'
maxabs=$(cat $TMPDIR/${SCAN}_skip_mc_abs.rms | sort -n | tail -1)

echo 'Calculating FD > 0.2; count the values'
fds=$(cat $TMPDIR/${SCAN}_skip_mc_rel.rms | sort -r)
count=0
limit=0.2
for v in $fds
do
result=$(bc -l <<< $v)s
if (( $(echo "$result > $limit" |bc -l) )); then
count=$(($count+1))
else
break
fi
done
numovp2=$count

echo 'Calculating voxel tSNR'
voxtsnr=$(fslstats $TMPDIR/${SCAN}_skip_mc_tsnr -m)

echo 'Calculating mean BOLD'
boldmn=$(fslstats $TMPDIR/${SCAN}_skip_mc_mean -m)

echo 'Calculating mean STD BOLD'
boldstd=$(fslstats $TMPDIR/${SCAN}_skip_mc_std -m)

bet $TMPDIR/${SCAN}_skip_mc_mean $TMPDIR/${SCAN}_skip_mc_mean_brain -m
echo 'Calculating in-brain tSNR (similar to slice-based tSNR)'
slsnr=$(fslstats  $TMPDIR/${SCAN}_skip_mc_tsnr -k $TMPDIR/${SCAN}_skip_mc_mean_brain_mask -m)

# Get values from .json (header)

# Run name 
runnm=($(jq -r '.TaskName' $DATAPATH/${SCAN}.json ))

# Acquisition time (hh:mm)
actime=($(jq -r '.AcquisitionTime' $DATAPATH/${SCAN}.json | cut -d":" -f1,2))

# Voxel dimensions
voxx=$(fslinfo $DATAPATH/$SCAN | awk 'NR==7 {print $2}')
voxx=$(printf '%.1f' $voxx)
voxy=$(fslinfo $DATAPATH/$SCAN | awk 'NR==8 {print $2}')
voxy=$(printf '%.1f' $voxy)
voxz=$(fslinfo $DATAPATH/$SCAN | awk 'NR==9 {print $2}')
voxz=$(printf '%.1f' $voxz)
if [[ $voxx == $voxy && $voxy == $voxz ]]; then
voxsize="${voxx}_iso"
else 
voxsize=${voxx}x${voxy}x${voxz}
fi

# Number of slices
zdim=$(fslinfo $DATAPATH/$SCAN | awk 'NR==4 {print $2}')

# TR (s)
TR=($(jq -r '.RepetitionTime' $DATAPATH/${SCAN}.json))

# Number of volumes is $totpts variable from above
vols=$(fslinfo $DATAPATH/$SCAN | awk 'NR==5 {print $2}')

# TE (ms)
TE=$(jq -r '.EchoTime' $DATAPATH/${SCAN}.json | awk 'NF{print $1*1000}' OFMT="%.1f" )

# Acceleration factor (SMS.in-plane)
SMS=($(jq -r '.MultibandAccelerationFactor' $DATAPATH/${SCAN}.json))
if [[ $SMS = 'false' ]]; then
echo 'Multiband field is empty'
SMS=0
fi

inplane=$(jq -e 'has("ParallelReductionFactorInPlane")' $DATAPATH/${SCAN}.json )
if [[ $inplane = 'false' ]]; then
echo 'In-plane field is empty'
inplane=0
fi

acc="${SMS}-${inplane}"

#Print values to csv
#did not add .json file values yet 
printf '%s\n %s\n %s\n %s\n %s\n %s\n %s\n %s\n %s\n %s\n %s\n %s\n %s\n %s\n %s\n %s\n' 'Task' 'Time' 'Vox' 'Slices' 'TR (s)' 'vols' 'TE (ms)' 'Acc' 'maxFD (mm)' 'meanFD (mm)' 'maxAbsMot (mm)' 'FD>0.2' 'vox-tSNR' 'sl-tSNR' 'mean BOLD' 'std BOLD' | paste -sd ',' > $OUTPATH/${SCAN}_qcvals.csv
printf '%s\n %s\n %s\n %s\n %.2f, %.0f, %.1f, %s\n %.3f, %.3f, %.3f, %s\n %.1f, %.1f, %.0f, %.0f' $runnm $actime $voxsize $zdim $TR $vols $TE $acc $maxfd $meanfd $maxabs $numovp2 $voxtsnr $slsnr $boldmn $boldstd | paste -sd ',' >> $OUTPATH/${SCAN}_qcvals.csv
cat $OUTPATH/${SCAN}_qcvals.csv

# SLICER IMAGES


#Combine tables across runs to make session QC page
#paste -d , input1.csv input2.csv > combined.csv

### END QC
