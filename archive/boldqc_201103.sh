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

#Print values to csv
printf '%.3f, %.3f, %.3f, %s\n' $maxfd $meanfd $maxabs $numovp2 | paste -sd ',' > $OUTPATH/${SCAN}_qcvals.csv

# SLICER IMAGES

OUTPATH_BASE=/Users/sec9607/Documents/MRI_data/sub-${SUB}/ses-${SESS}/preproc_func/$SCAN
SLICERBASEDIROLD=/Users/sec9607/Northwestern\ University/Anna\ Michelle\ Holubecki\ -\ braga_lab/data_collection/mri_cti/fMRIPILOT1030/slicers
SLICERBASEDIR=/Users/sec9607/Documents/slicers
ln -s "$SLICERBASEDIROLD" $SLICERBASEDIR

WKDIR=~/Downloads/slicerims
mkdir -p $WKDIR

#MEAN

SLICERDIR=$SLICERBASEDIR/mean
mkdir -p "$SLICERDIR"

#CBS1p5_run-01 AXIAL
sequence_name=sub-fMRIPILOT1030_ses-fMRIPILOT1030_task-REST_run-01_acq-CBS1p5_bold
sequence_tag=CBS1p5_run-01
underlay=$OUTPATH_BASE/${sequence_name}/${sequence_name}_skip_mc_mean.nii.gz
outfile=$SLICERDIR/${SUB}_${sequence_tag}_meanBOLD.png
filename=$(basename "$underlay")
nmun="${filename%%.*}"
filename3=$(basename "$outfile")
nmout="${filename3%.*}"
zdim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 4 {print}')
numslices=$(($zdim/28))
xdim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 2 {print}')
width=$((7*$xdim))
ydim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 3 {print}')
slicer $underlay -u -S $numslices $width $outfile
convert $outfile -resize 700 $outfile
convert $outfile -background White -pointsize 20 label:$nmout +swap -gravity North-West -append $outfile

#CBS1p5_run-01 SAGITTTAL
sequence_name=sub-fMRIPILOT1030_ses-fMRIPILOT1030_task-REST_run-01_acq-CBS1p5_bold
sequence_tag=CBS1p5_run-01
underlay=$OUTPATH_BASE/${sequence_name}/${sequence_name}_skip_mc_mean.nii.gz
outfile=$SLICERDIR/${SUB}_${sequence_tag}_meanBOLD_sag.png
filename=$(basename "$underlay")
nmun="${filename%%.*}"
filename3=$(basename "$outfile")
nmout="${filename3%.*}"
zdim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 4 {print}')
xdim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 2 {print}')
ydim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 3 {print}')
numslices=$(($xdim/28))
xthick=$(($xdim-15))
width=$((7*$ydim))
fslroi $underlay ${WKDIR}/ov_roi.nii.gz 15 $xthick 0 $ydim 0 $zdim
fslswapdim ${WKDIR}/ov_roi.nii.gz y z -x ${WKDIR}/${nmov}
slicer ${WKDIR}/${nmov} -u -S $numslices $width $outfile
convert $outfile -resize 700 $outfile
convert $outfile -background White -pointsize 20 label:$nmout +swap -gravity North-West -append $outfile

#CBS2p4_run-02 AXIAL
sequence_name=sub-fMRIPILOT1030_ses-fMRIPILOT1030_task-REST_run-02_acq-CBS2p4_bold
sequence_tag=CBS2p4_run-02
underlay=$OUTPATH_BASE/${sequence_name}/${sequence_name}_skip_mc_mean.nii.gz
outfile=$SLICERDIR/${SUB}_${sequence_tag}_meanBOLD.png
filename=$(basename "$underlay")
nmun="${filename%%.*}"
filename3=$(basename "$outfile")
nmout="${filename3%.*}"
zdim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 4 {print}')
numslices=$(($zdim/28))
xdim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 2 {print}')
width=$((7*$xdim))
ydim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 3 {print}')
slicer $underlay -u -S $numslices $width $outfile
convert $outfile -resize 700 $outfile
convert $outfile -background White -pointsize 20 label:$nmout +swap -gravity North-West -append $outfile

#CBS2p4_run-02 SAGITTAL
sequence_name=sub-fMRIPILOT1030_ses-fMRIPILOT1030_task-REST_run-02_acq-CBS2p4_bold
sequence_tag=CBS2p4_run-02
underlay=$OUTPATH_BASE/${sequence_name}/${sequence_name}_skip_mc_mean.nii.gz
outfile=$SLICERDIR/${SUB}_${sequence_tag}_meanBOLD_sag.png
filename=$(basename "$underlay")
nmun="${filename%%.*}"
filename3=$(basename "$outfile")
nmout="${filename3%.*}"
zdim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 4 {print}')
xdim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 2 {print}')
ydim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 3 {print}')
numslices=$(($xdim/28))
xthick=$(($xdim-15))
width=$((7*$ydim))
fslroi $underlay ${WKDIR}/ov_roi.nii.gz 15 $xthick 0 $ydim 0 $zdim
fslswapdim ${WKDIR}/ov_roi.nii.gz y z -x ${WKDIR}/${nmov}
slicer ${WKDIR}/${nmov} -u -S $numslices $width $outfile
convert $outfile -resize 700 $outfile
convert $outfile -background White -pointsize 20 label:$nmout +swap -gravity North-West -append $outfile

#CBS1p5_run-03 AXIAL
sequence_name=sub-fMRIPILOT1030_ses-fMRIPILOT1030_task-REST_run-03_acq-CBS1p5_bold
sequence_tag=CBS1p5_run-03
underlay=$OUTPATH_BASE/${sequence_name}/${sequence_name}_skip_mc_mean.nii.gz
outfile=$SLICERDIR/${SUB}_${sequence_tag}_meanBOLD.png
filename=$(basename "$underlay")
nmun="${filename%%.*}"
filename3=$(basename "$outfile")
nmout="${filename3%.*}"
zdim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 4 {print}')
numslices=$(($zdim/28))
xdim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 2 {print}')
width=$((7*$xdim))
ydim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 3 {print}')
slicer $underlay -u -S $numslices $width $outfile
convert $outfile -resize 700 $outfile
convert $outfile -background White -pointsize 20 label:$nmout +swap -gravity North-West -append $outfile

#CBS1p5_run-03 SAGITTAL
sequence_name=sub-fMRIPILOT1030_ses-fMRIPILOT1030_task-REST_run-03_acq-CBS1p5_bold
sequence_tag=CBS1p5_run-03
underlay=$OUTPATH_BASE/${sequence_name}/${sequence_name}_skip_mc_mean.nii.gz
outfile=$SLICERDIR/${SUB}_${sequence_tag}_meanBOLD_sag.png
filename=$(basename "$underlay")
nmun="${filename%%.*}"
filename3=$(basename "$outfile")
nmout="${filename3%.*}"
zdim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 4 {print}')
xdim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 2 {print}')
ydim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 3 {print}')
numslices=$(($xdim/28))
xthick=$(($xdim-15))
width=$((7*$ydim))
fslroi $underlay ${WKDIR}/ov_roi.nii.gz 15 $xthick 0 $ydim 0 $zdim
fslswapdim ${WKDIR}/ov_roi.nii.gz y z -x ${WKDIR}/${nmov}
slicer ${WKDIR}/${nmov} -u -S $numslices $width $outfile
convert $outfile -resize 700 $outfile
convert $outfile -background White -pointsize 20 label:$nmout +swap -gravity North-West -append $outfile

#CBS2p4_run-04 AXIAL
sequence_name=sub-fMRIPILOT1030_ses-fMRIPILOT1030_task-REST_run-04_acq-CBS2p4_bold
sequence_tag=CBS2p4_run-04
underlay=$OUTPATH_BASE/${sequence_name}/${sequence_name}_skip_mc_mean.nii.gz
outfile=$SLICERDIR/${SUB}_${sequence_tag}_meanBOLD.png
filename=$(basename "$underlay")
nmun="${filename%%.*}"
filename3=$(basename "$outfile")
nmout="${filename3%.*}"
zdim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 4 {print}')
numslices=$(($zdim/28))
xdim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 2 {print}')
width=$((7*$xdim))
ydim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 3 {print}')
slicer $underlay -u -S $numslices $width $outfile
convert $outfile -resize 700 $outfile
convert $outfile -background White -pointsize 20 label:$nmout +swap -gravity North-West -append $outfile

#CBS2p4_run-04 SAGITTAL
sequence_name=sub-fMRIPILOT1030_ses-fMRIPILOT1030_task-REST_run-04_acq-CBS2p4_bold
sequence_tag=CBS2p4_run-04
underlay=$OUTPATH_BASE/${sequence_name}/${sequence_name}_skip_mc_mean.nii.gz
outfile=$SLICERDIR/${SUB}_${sequence_tag}_meanBOLD_sag.png
filename=$(basename "$underlay")
nmun="${filename%%.*}"
filename3=$(basename "$outfile")
nmout="${filename3%.*}"
zdim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 4 {print}')
xdim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 2 {print}')
ydim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 3 {print}')
numslices=$(($xdim/28))
xthick=$(($xdim-15))
width=$((7*$ydim))
fslroi $underlay ${WKDIR}/ov_roi.nii.gz 15 $xthick 0 $ydim 0 $zdim
fslswapdim ${WKDIR}/ov_roi.nii.gz y z -x ${WKDIR}/${nmov}
slicer ${WKDIR}/${nmov} -u -S $numslices $width $outfile
convert $outfile -resize 700 $outfile
convert $outfile -background White -pointsize 20 label:$nmout +swap -gravity North-West -append $outfile

#CBS1p5_run-05 AXIAL
sequence_name=sub-fMRIPILOT1030_ses-fMRIPILOT1030_task-REST_run-05_acq-CBS1p5_bold
sequence_tag=CBS1p5_run-05
underlay=$OUTPATH_BASE/${sequence_name}/${sequence_name}_skip_mc_mean.nii.gz
outfile=$SLICERDIR/${SUB}_${sequence_tag}_meanBOLD.png
filename=$(basename "$underlay")
nmun="${filename%%.*}"
filename3=$(basename "$outfile")
nmout="${filename3%.*}"
zdim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 4 {print}')
numslices=$(($zdim/28))
xdim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 2 {print}')
width=$((7*$xdim))
ydim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 3 {print}')
slicer $underlay -u -S $numslices $width $outfile
convert $outfile -resize 700 $outfile
convert $outfile -background White -pointsize 20 label:$nmout +swap -gravity North-West -append $outfile

#CBS1p5_run-05 SAGITTAL
sequence_name=sub-fMRIPILOT1030_ses-fMRIPILOT1030_task-REST_run-05_acq-CBS1p5_bold
sequence_tag=CBS1p5_run-05
underlay=$OUTPATH_BASE/${sequence_name}/${sequence_name}_skip_mc_mean.nii.gz
outfile=$SLICERDIR/${SUB}_${sequence_tag}_meanBOLD_sag.png
filename=$(basename "$underlay")
nmun="${filename%%.*}"
filename3=$(basename "$outfile")
nmout="${filename3%.*}"
zdim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 4 {print}')
xdim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 2 {print}')
ydim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 3 {print}')
numslices=$(($xdim/28))
xthick=$(($xdim-15))
width=$((7*$ydim))
fslroi $underlay ${WKDIR}/ov_roi.nii.gz 15 $xthick 0 $ydim 0 $zdim
fslswapdim ${WKDIR}/ov_roi.nii.gz y z -x ${WKDIR}/${nmov}
slicer ${WKDIR}/${nmov} -u -S $numslices $width $outfile
convert $outfile -resize 700 $outfile
convert $outfile -background White -pointsize 20 label:$nmout +swap -gravity North-West -append $outfile

#CBS2p4_run-06 AXIAL
sequence_name=sub-fMRIPILOT1030_ses-fMRIPILOT1030_task-REST_run-06_acq-CBS2p4_bold
sequence_tag=CBS2p4_run-06
nderlay=$OUTPATH_BASE/${sequence_name}/${sequence_name}_skip_mc_mean.nii.gz
outfile=$SLICERDIR/${SUB}_${sequence_tag}_meanBOLD.png
filename=$(basename "$underlay")
nmun="${filename%%.*}"
filename3=$(basename "$outfile")
nmout="${filename3%.*}"
zdim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 4 {print}')
numslices=$(($zdim/28))
xdim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 2 {print}')
width=$((7*$xdim))
ydim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 3 {print}')
slicer $underlay -u -S $numslices $width $outfile
convert $outfile -resize 700 $outfile
convert $outfile -background White -pointsize 20 label:$nmout +swap -gravity North-West -append $outfile

#CBS2p4_run-06 SAGITTAL
sequence_name=sub-fMRIPILOT1030_ses-fMRIPILOT1030_task-REST_run-06_acq-CBS2p4_bold
sequence_tag=CBS2p4_run-06
underlay=$OUTPATH_BASE/${sequence_name}/${sequence_name}_skip_mc_mean.nii.gz
outfile=$SLICERDIR/${SUB}_${sequence_tag}_meanBOLD_sag.png
filename=$(basename "$underlay")
nmun="${filename%%.*}"
filename3=$(basename "$outfile")
nmout="${filename3%.*}"
zdim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 4 {print}')
xdim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 2 {print}')
ydim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 3 {print}')
numslices=$(($xdim/28))
xthick=$(($xdim-15))
width=$((7*$ydim))
fslroi $underlay ${WKDIR}/ov_roi.nii.gz 15 $xthick 0 $ydim 0 $zdim
fslswapdim ${WKDIR}/ov_roi.nii.gz y z -x ${WKDIR}/${nmov}
slicer ${WKDIR}/${nmov} -u -S $numslices $width $outfile
convert $outfile -resize 700 $outfile
convert $outfile -background White -pointsize 20 label:$nmout +swap -gravity North-West -append $outfile


#STD

SLICERDIR=$SLICERBASEDIR/std
mkdir -p $SLICERDIR

#CBS1p5_run-01 AXIAL
sequence_name=sub-fMRIPILOT1030_ses-fMRIPILOT1030_task-REST_run-01_acq-CBS1p5_bold
sequence_tag=3ME2p0TR1p5_echo-1
underlay=$OUTPATH_BASE/${sequence_name}/${sequence_name}_skip_mc_std.nii.gz
outfile=$SLICERDIR/${SUB}_${sequence_tag}_stdBOLD.png
filename=$(basename "$underlay")
nmun="${filename%%.*}"
filename3=$(basename "$outfile")
nmout="${filename3%.*}"
zdim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 4 {print}')
numslices=$(($zdim/28))
xdim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 2 {print}')
width=$((7*$xdim))
ydim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 3 {print}')
slicer $underlay -u -S $numslices $width $outfile
convert $outfile -resize 700 $outfile
convert $outfile -background White -pointsize 20 label:$nmout +swap -gravity North-West -append $outfile


#CBS1p5_run-01 SAGITTAL
sequence_name=sub-fMRIPILOT1030_ses-fMRIPILOT1030_task-REST_run-01_acq-CBS1p5_bold
sequence_tag=3ME2p0TR1p5_echo-1
underlay=$OUTPATH_BASE/${sequence_name}/${sequence_name}_skip_mc_std.nii.gz
outfile=$SLICERDIR/${SUB}_${sequence_tag}_stdBOLD_sag.png
filename=$(basename "$underlay")
nmun="${filename%%.*}"
filename3=$(basename "$outfile")
nmout="${filename3%.*}"
zdim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 4 {print}')
xdim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 2 {print}')
ydim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 3 {print}')
numslices=$(($xdim/28))
xthick=$(($xdim-15))
width=$((7*$ydim))
fslroi $underlay ${WKDIR}/ov_roi.nii.gz 15 $xthick 0 $ydim 0 $zdim
fslswapdim ${WKDIR}/ov_roi.nii.gz y z -x ${WKDIR}/${nmov}
slicer ${WKDIR}/${nmov} -u -S $numslices $width $outfile
convert $outfile -resize 700 $outfile
convert $outfile -background White -pointsize 20 label:$nmout +swap -gravity North-West -append $outfile

#CBS2p4_run-02 AXIAL
sequence_name=sub-fMRIPILOT1030_ses-fMRIPILOT1030_task-REST_run-02_acq-CBS2p4_bold
sequence_tag=CBS2p4_run-02
underlay=$OUTPATH_BASE/${sequence_name}/${sequence_name}_skip_mc_std.nii.gz
outfile=$SLICERDIR/${SUB}_${sequence_tag}_stdBOLD.png
filename=$(basename "$underlay")
nmun="${filename%%.*}"
filename3=$(basename "$outfile")
nmout="${filename3%.*}"
zdim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 4 {print}')
numslices=$(($zdim/28))
xdim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 2 {print}')
width=$((7*$xdim))
ydim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 3 {print}')
slicer $underlay -u -S $numslices $width $outfile
convert $outfile -resize 700 $outfile
convert $outfile -background White -pointsize 20 label:$nmout +swap -gravity North-West -append $outfile

#CBS2p4_run-02 SAGITTAL
sequence_name=sub-fMRIPILOT1030_ses-fMRIPILOT1030_task-REST_run-02_acq-CBS2p4_bold
sequence_tag=CBS2p4_run-02
underlay=$OUTPATH_BASE/${sequence_name}/${sequence_name}_skip_mc_std.nii.gz
outfile=$SLICERDIR/${SUB}_${sequence_tag}_stdBOLD_sag.png
filename=$(basename "$underlay")
nmun="${filename%%.*}"
filename3=$(basename "$outfile")
nmout="${filename3%.*}"
zdim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 4 {print}')
xdim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 2 {print}')
ydim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 3 {print}')
numslices=$(($xdim/28))
xthick=$(($xdim-15))
width=$((7*$ydim))
fslroi $underlay ${WKDIR}/ov_roi.nii.gz 15 $xthick 0 $ydim 0 $zdim
fslswapdim ${WKDIR}/ov_roi.nii.gz y z -x ${WKDIR}/${nmov}
slicer ${WKDIR}/${nmov} -u -S $numslices $width $outfile
convert $outfile -resize 700 $outfile
convert $outfile -background White -pointsize 20 label:$nmout +swap -gravity North-West -append $outfile

#CBS1p5_run-03 AXIAL
sequence_name=sub-fMRIPILOT1030_ses-fMRIPILOT1030_task-REST_run-03_acq-CBS1p5_bold
sequence_tag=CBS1p5_run-03
underlay=$OUTPATH_BASE/${sequence_name}/${sequence_name}_skip_mc_std.nii.gz
outfile=$SLICERDIR/${SUB}_${sequence_tag}_stdBOLD.png
filename=$(basename "$underlay")
nmun="${filename%%.*}"
filename3=$(basename "$outfile")
nmout="${filename3%.*}"
zdim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 4 {print}')
numslices=$(($zdim/28))
xdim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 2 {print}')
width=$((7*$xdim))
ydim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 3 {print}')
slicer $underlay -u -S $numslices $width $outfile
convert $outfile -resize 700 $outfile
convert $outfile -background White -pointsize 20 label:$nmout +swap -gravity North-West -append $outfile

#CBS1p5_run-03 SAGITTAL
sequence_name=sub-fMRIPILOT1030_ses-fMRIPILOT1030_task-REST_run-03_acq-CBS1p5_bold
sequence_tag=CBS1p5_run-03
underlay=$OUTPATH_BASE/${sequence_name}/${sequence_name}_skip_mc_std.nii.gz
outfile=$SLICERDIR/${SUB}_${sequence_tag}_stdBOLD_sag.png
filename=$(basename "$underlay")
nmun="${filename%%.*}"
filename3=$(basename "$outfile")
nmout="${filename3%.*}"
zdim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 4 {print}')
xdim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 2 {print}')
ydim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 3 {print}')
numslices=$(($xdim/28))
xthick=$(($xdim-15))
width=$((7*$ydim))
fslroi $underlay ${WKDIR}/ov_roi.nii.gz 15 $xthick 0 $ydim 0 $zdim
fslswapdim ${WKDIR}/ov_roi.nii.gz y z -x ${WKDIR}/${nmov}
slicer ${WKDIR}/${nmov} -u -S $numslices $width $outfile
convert $outfile -resize 700 $outfile
convert $outfile -background White -pointsize 20 label:$nmout +swap -gravity North-West -append $outfile

#CBS2p4_run-04 AXIAL
sequence_name=sub-fMRIPILOT1030_ses-fMRIPILOT1030_task-REST_run-04_acq-CBS2p4_bold
sequence_tag=CBS2p4_run-04
underlay=$OUTPATH_BASE/${sequence_name}/${sequence_name}_skip_mc_std.nii.gz
outfile=$SLICERDIR/${SUB}_${sequence_tag}_stdBOLD.png
filename=$(basename "$underlay")
nmun="${filename%%.*}"
filename3=$(basename "$outfile")
nmout="${filename3%.*}"
zdim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 4 {print}')
numslices=$(($zdim/28))
xdim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 2 {print}')
width=$((7*$xdim))
ydim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 3 {print}')
slicer $underlay -u -S $numslices $width $outfile
convert $outfile -resize 700 $outfile
convert $outfile -background White -pointsize 20 label:$nmout +swap -gravity North-West -append $outfile

#CBS2p4_run-04 SAGITTAL
sequence_name=sub-fMRIPILOT1030_ses-fMRIPILOT1030_task-REST_run-04_acq-CBS2p4_bold
sequence_tag=CBS2p4_run-04
underlay=$OUTPATH_BASE/${sequence_name}/${sequence_name}_skip_mc_std.nii.gz
outfile=$SLICERDIR/${SUB}_${sequence_tag}_stdBOLD_sag.png
filename=$(basename "$underlay")
nmun="${filename%%.*}"
filename3=$(basename "$outfile")
nmout="${filename3%.*}"
zdim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 4 {print}')
xdim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 2 {print}')
ydim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 3 {print}')
numslices=$(($xdim/28))
xthick=$(($xdim-15))
width=$((7*$ydim))
fslroi $underlay ${WKDIR}/ov_roi.nii.gz 15 $xthick 0 $ydim 0 $zdim
fslswapdim ${WKDIR}/ov_roi.nii.gz y z -x ${WKDIR}/${nmov}
slicer ${WKDIR}/${nmov} -u -S $numslices $width $outfile
convert $outfile -resize 700 $outfile
convert $outfile -background White -pointsize 20 label:$nmout +swap -gravity North-West -append $outfile

#CBS1p5_run-05 AXIAL
sequence_name=sub-fMRIPILOT1030_ses-fMRIPILOT1030_task-REST_run-05_acq-CBS1p5_bold
sequence_tag=CBS1p5_run-05
underlay=$OUTPATH_BASE/${sequence_name}/${sequence_name}_skip_mc_std.nii.gz
outfile=$SLICERDIR/${SUB}_${sequence_tag}_stdBOLD.png
filename=$(basename "$underlay")
nmun="${filename%%.*}"
filename3=$(basename "$outfile")
nmout="${filename3%.*}"
zdim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 4 {print}')
numslices=$(($zdim/28))
xdim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 2 {print}')
width=$((7*$xdim))
ydim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 3 {print}')
slicer $underlay -u -S $numslices $width $outfile
convert $outfile -resize 700 $outfile
convert $outfile -background White -pointsize 20 label:$nmout +swap -gravity North-West -append $outfile

#CBS1p5_run-05 SAGITTAL
sequence_name=sub-fMRIPILOT1030_ses-fMRIPILOT1030_task-REST_run-05_acq-CBS1p5_bold
sequence_tag=CBS1p5_run-05
underlay=$OUTPATH_BASE/${sequence_name}/${sequence_name}_skip_mc_std.nii.gz
outfile=$SLICERDIR/${SUB}_${sequence_tag}_stdBOLD_sag.png
filename=$(basename "$underlay")
nmun="${filename%%.*}"
filename3=$(basename "$outfile")
nmout="${filename3%.*}"
zdim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 4 {print}')
xdim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 2 {print}')
ydim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 3 {print}')
numslices=$(($xdim/28))
xthick=$(($xdim-15))
width=$((7*$ydim))
fslroi $underlay ${WKDIR}/ov_roi.nii.gz 15 $xthick 0 $ydim 0 $zdim
fslswapdim ${WKDIR}/ov_roi.nii.gz y z -x ${WKDIR}/${nmov}
slicer ${WKDIR}/${nmov} -u -S $numslices $width $outfile
convert $outfile -resize 700 $outfile
convert $outfile -background White -pointsize 20 label:$nmout +swap -gravity North-West -append $outfile


#CBS2p4_run-06 AXIAL
sequence_name=sub-fMRIPILOT1030_ses-fMRIPILOT1030_task-REST_run-06_acq-CBS2p4_bold
sequence_tag=CBS2p4_run-06
underlay=$OUTPATH_BASE/${sequence_name}/${sequence_name}_skip_mc_std.nii.gz
outfile=$SLICERDIR/${SUB}_${sequence_tag}_stdBOLD.png
filename=$(basename "$underlay")
nmun="${filename%%.*}"
filename3=$(basename "$outfile")
nmout="${filename3%.*}"
zdim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 4 {print}')
numslices=$(($zdim/28))
xdim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 2 {print}')
width=$((7*$xdim))
ydim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 3 {print}')
slicer $underlay -u -S $numslices $width $outfile
convert $outfile -resize 700 $outfile
convert $outfile -background White -pointsize 20 label:$nmout +swap -gravity North-West -append $outfile


#CBS2p4_run-06 SAGITTAL
sequence_name=sub-fMRIPILOT1030_ses-fMRIPILOT1030_task-REST_run-06_acq-CBS2p4_bold
sequence_tag=CBS2p4_run-06
underlay=$OUTPATH_BASE/${sequence_name}/${sequence_name}_skip_mc_std.nii.gz
outfile=$SLICERDIR/${SUB}_${sequence_tag}_stdBOLD_sag.png
filename=$(basename "$underlay")
nmun="${filename%%.*}"
filename3=$(basename "$outfile")
nmout="${filename3%.*}"
zdim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 4 {print}')
xdim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 2 {print}')
ydim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 3 {print}')
numslices=$(($xdim/28))
xthick=$(($xdim-15))
width=$((7*$ydim))
fslroi $underlay ${WKDIR}/ov_roi.nii.gz 15 $xthick 0 $ydim 0 $zdim
fslswapdim ${WKDIR}/ov_roi.nii.gz y z -x ${WKDIR}/${nmov}
slicer ${WKDIR}/${nmov} -u -S $numslices $width $outfile
convert $outfile -resize 700 $outfile
convert $outfile -background White -pointsize 20 label:$nmout +swap -gravity North-West -append $outfile


#tSNR

SLICERDIR=$SLICERBASEDIR/tsnr
mkdir -p $SLICERDIR


#CBS1p5_run-01 AXIAL
sequence_name=sub-fMRIPILOT1030_ses-fMRIPILOT1030_task-REST_run-01_acq-CBS1p5_bold
sequence_tag=3ME2p0TR1p5_echo-1
underlay=$OUTPATH_BASE/${sequence_name}/${sequence_name}_skip_mc_tsnr.nii.gz
outfile=$SLICERDIR/${SUB}_${sequence_tag}_BOLD_tsnr.png
filename=$(basename "$underlay")
nmun="${filename%%.*}"
filename3=$(basename "$outfile")
nmout="${filename3%.*}"
zdim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 4 {print}')
numslices=$(($zdim/28))
xdim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 2 {print}')
width=$((7*$xdim))
ydim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 3 {print}')
slicer $underlay -l $FSLDIR/etc/luts/render3.lut -i 0 100 -u -S $numslices $width $outfile
convert $outfile -resize 700 $outfile
convert $outfile -background White -pointsize 20 label:$nmout +swap -gravity North-West -append $outfile



#CBS1p5_run-01 SAGITTAL
sequence_name=sub-fMRIPILOT1030_ses-fMRIPILOT1030_task-REST_run-01_acq-CBS1p5_bold
sequence_tag=3ME2p0TR1p5_echo-1
underlay=$OUTPATH_BASE/${sequence_name}/${sequence_name}_skip_mc_tsnr.nii.gz
outfile=$SLICERDIR/${SUB}_${sequence_tag}_BOLD_tsnr_sag.png
filename=$(basename "$underlay")
nmun="${filename%%.*}"
filename3=$(basename "$outfile")
nmout="${filename3%.*}"
zdim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 4 {print}')
xdim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 2 {print}')
ydim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 3 {print}')
numslices=$(($xdim/28))
xthick=$(($xdim-15))
width=$((7*$ydim))
fslroi $underlay ${WKDIR}/ov_roi.nii.gz 15 $xthick 0 $ydim 0 $zdim
fslswapdim ${WKDIR}/ov_roi.nii.gz y z -x ${WKDIR}/${nmov}
slicer ${WKDIR}/${nmov} -l $FSLDIR/etc/luts/render3.lut -i 0 100 -u -S $numslices $width $outfile
convert $outfile -resize 700 $outfile
convert $outfile -background White -pointsize 20 label:$nmout +swap -gravity North-West -append $outfile

#CBS2p4_run-02 AXIAL
sequence_name=sub-fMRIPILOT1030_ses-fMRIPILOT1030_task-REST_run-02_acq-CBS2p4_bold
sequence_tag=CBS2p4_run-02
underlay=$OUTPATH_BASE/${sequence_name}/${sequence_name}_skip_mc_tsnr.nii.gz
outfile=$SLICERDIR/${SUB}_${sequence_tag}_BOLD_tsnr.png
filename=$(basename "$underlay")
nmun="${filename%%.*}"
filename3=$(basename "$outfile")
nmout="${filename3%.*}"
zdim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 4 {print}')
numslices=$(($zdim/28))
xdim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 2 {print}')
width=$((7*$xdim))
ydim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 3 {print}')
slicer $underlay -l $FSLDIR/etc/luts/render3.lut -i 0 100 -u -S $numslices $width $outfile
convert $outfile -resize 700 $outfile
convert $outfile -background White -pointsize 20 label:$nmout +swap -gravity North-West -append $outfile

#CBS2p4_run-02 SAGITTAL
sequence_name=sub-fMRIPILOT1030_ses-fMRIPILOT1030_task-REST_run-02_acq-CBS2p4_bold
sequence_tag=CBS2p4_run-02
underlay=$OUTPATH_BASE/${sequence_name}/${sequence_name}_skip_mc_tsnr.nii.gz
outfile=$SLICERDIR/${SUB}_${sequence_tag}_BOLD_tsnr_sag.png
filename=$(basename "$underlay")
nmun="${filename%%.*}"
filename3=$(basename "$outfile")
nmout="${filename3%.*}"
zdim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 4 {print}')
xdim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 2 {print}')
ydim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 3 {print}')
numslices=$(($xdim/28))
xthick=$(($xdim-15))
width=$((7*$ydim))
fslroi $underlay ${WKDIR}/ov_roi.nii.gz 15 $xthick 0 $ydim 0 $zdim
fslswapdim ${WKDIR}/ov_roi.nii.gz y z -x ${WKDIR}/${nmov}
slicer ${WKDIR}/${nmov} -l $FSLDIR/etc/luts/render3.lut -i 0 100 -u -S $numslices $width $outfile
convert $outfile -resize 700 $outfile
convert $outfile -background White -pointsize 20 label:$nmout +swap -gravity North-West -append $outfile


#CBS1p5_run-03 AXIAL
sequence_name=sub-fMRIPILOT1030_ses-fMRIPILOT1030_task-REST_run-03_acq-CBS1p5_bold
sequence_tag=CBS1p5_run-03
underlay=$OUTPATH_BASE/${sequence_name}/${sequence_name}_skip_mc_tsnr.nii.gz
outfile=$SLICERDIR/${SUB}_${sequence_tag}_BOLD_tsnr.png
filename=$(basename "$underlay")
nmun="${filename%%.*}"
filename3=$(basename "$outfile")
nmout="${filename3%.*}"
zdim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 4 {print}')
numslices=$(($zdim/28))
xdim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 2 {print}')
width=$((7*$xdim))
ydim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 3 {print}')
slicer $underlay -l $FSLDIR/etc/luts/render3.lut -i 0 100 -u -S $numslices $width $outfile
convert $outfile -resize 700 $outfile
convert $outfile -background White -pointsize 20 label:$nmout +swap -gravity North-West -append $outfile


#CBS1p5_run-03 SAGITTAL
sequence_name=sub-fMRIPILOT1030_ses-fMRIPILOT1030_task-REST_run-03_acq-CBS1p5_bold
sequence_tag=CBS1p5_run-03
underlay=$OUTPATH_BASE/${sequence_name}/${sequence_name}_skip_mc_tsnr.nii.gz
outfile=$SLICERDIR/${SUB}_${sequence_tag}_BOLD_tsnr_sag.png
filename=$(basename "$underlay")
nmun="${filename%%.*}"
filename3=$(basename "$outfile")
nmout="${filename3%.*}"
zdim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 4 {print}')
xdim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 2 {print}')
ydim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 3 {print}')
numslices=$(($xdim/28))
xthick=$(($xdim-15))
width=$((7*$ydim))
fslroi $underlay ${WKDIR}/ov_roi.nii.gz 15 $xthick 0 $ydim 0 $zdim
fslswapdim ${WKDIR}/ov_roi.nii.gz y z -x ${WKDIR}/${nmov}
slicer ${WKDIR}/${nmov} -l $FSLDIR/etc/luts/render3.lut -i 0 100 -u -S $numslices $width $outfile
convert $outfile -resize 700 $outfile
convert $outfile -background White -pointsize 20 label:$nmout +swap -gravity North-West -append $outfile

#CBS2p4_run-04 AXIAL
sequence_name=sub-fMRIPILOT1030_ses-fMRIPILOT1030_task-REST_run-04_acq-CBS2p4_bold
sequence_tag=CBS2p4_run-04
underlay=$OUTPATH_BASE/${sequence_name}/${sequence_name}_skip_mc_tsnr.nii.gz
outfile=$SLICERDIR/${SUB}_${sequence_tag}_BOLD_tsnr.png
filename=$(basename "$underlay")
nmun="${filename%%.*}"
filename3=$(basename "$outfile")
nmout="${filename3%.*}"
zdim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 4 {print}')
numslices=$(($zdim/28))
xdim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 2 {print}')
width=$((7*$xdim))
ydim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 3 {print}')
slicer $underlay -l $FSLDIR/etc/luts/render3.lut -i 0 100 -u -S $numslices $width $outfile
convert $outfile -resize 700 $outfile
convert $outfile -background White -pointsize 20 label:$nmout +swap -gravity North-West -append $outfile

#CBS2p4_run-04 SAGITTAL
sequence_name=sub-fMRIPILOT1030_ses-fMRIPILOT1030_task-REST_run-04_acq-CBS2p4_bold
sequence_tag=CBS2p4_run-04
underlay=$OUTPATH_BASE/${sequence_name}/${sequence_name}_skip_mc_tsnr.nii.gz
outfile=$SLICERDIR/${SUB}_${sequence_tag}_BOLD_tsnr_sag.png
filename=$(basename "$underlay")
nmun="${filename%%.*}"
filename3=$(basename "$outfile")
nmout="${filename3%.*}"
zdim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 4 {print}')
xdim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 2 {print}')
ydim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 3 {print}')
numslices=$(($xdim/28))
xthick=$(($xdim-15))
width=$((7*$ydim))
fslroi $underlay ${WKDIR}/ov_roi.nii.gz 15 $xthick 0 $ydim 0 $zdim
fslswapdim ${WKDIR}/ov_roi.nii.gz y z -x ${WKDIR}/${nmov}
slicer ${WKDIR}/${nmov} -l $FSLDIR/etc/luts/render3.lut -i 0 100 -u -S $numslices $width $outfile
convert $outfile -resize 700 $outfile
convert $outfile -background White -pointsize 20 label:$nmout +swap -gravity North-West -append $outfile

#CBS1p5_run-05 AXIAL
sequence_name=sub-fMRIPILOT1030_ses-fMRIPILOT1030_task-REST_run-05_acq-CBS1p5_bold
sequence_tag=CBS1p5_run-05
underlay=$OUTPATH_BASE/${sequence_name}/${sequence_name}_skip_mc_tsnr.nii.gz
outfile=$SLICERDIR/${SUB}_${sequence_tag}_BOLD_tsnr.png
filename=$(basename "$underlay")
nmun="${filename%%.*}"
filename3=$(basename "$outfile")
nmout="${filename3%.*}"
zdim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 4 {print}')
numslices=$(($zdim/28))
xdim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 2 {print}')
width=$((7*$xdim))
ydim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 3 {print}')
slicer $underlay -l $FSLDIR/etc/luts/render3.lut -i 0 100 -u -S $numslices $width $outfile
convert $outfile -resize 700 $outfile
convert $outfile -background White -pointsize 20 label:$nmout +swap -gravity North-West -append $outfile


#CBS1p5_run-05 SAGITTAL
sequence_name=sub-fMRIPILOT1030_ses-fMRIPILOT1030_task-REST_run-05_acq-CBS1p5_bold
sequence_tag=CBS1p5_run-05
underlay=$OUTPATH_BASE/${sequence_name}/${sequence_name}_skip_mc_tsnr.nii.gz
outfile=$SLICERDIR/${SUB}_${sequence_tag}_BOLD_tsnr_sag.png
filename=$(basename "$underlay")
nmun="${filename%%.*}"
filename3=$(basename "$outfile")
nmout="${filename3%.*}"
zdim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 4 {print}')
xdim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 2 {print}')
ydim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 3 {print}')
numslices=$(($xdim/28))
xthick=$(($xdim-15))
width=$((7*$ydim))
fslroi $underlay ${WKDIR}/ov_roi.nii.gz 15 $xthick 0 $ydim 0 $zdim
fslswapdim ${WKDIR}/ov_roi.nii.gz y z -x ${WKDIR}/${nmov}
slicer ${WKDIR}/${nmov} -l $FSLDIR/etc/luts/render3.lut -i 0 100 -u -S $numslices $width $outfile
convert $outfile -resize 700 $outfile
convert $outfile -background White -pointsize 20 label:$nmout +swap -gravity North-West -append $outfile

#CBS2p4_run-06 AXIAL
sequence_name=sub-fMRIPILOT1030_ses-fMRIPILOT1030_task-REST_run-06_acq-CBS2p4_bold
sequence_tag=CBS2p4_run-06
underlay=$OUTPATH_BASE/${sequence_name}/${sequence_name}_skip_mc_tsnr.nii.gz
outfile=$SLICERDIR/${SUB}_${sequence_tag}_BOLD_tsnr.png
filename=$(basename "$underlay")
nmun="${filename%%.*}"
filename3=$(basename "$outfile")
nmout="${filename3%.*}"
zdim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 4 {print}')
numslices=$(($zdim/28))
xdim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 2 {print}')
width=$((7*$xdim))
ydim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 3 {print}')
slicer $underlay -l $FSLDIR/etc/luts/render3.lut -i 0 100 -u -S $numslices $width $outfile
convert $outfile -resize 700 $outfile
convert $outfile -background White -pointsize 20 label:$nmout +swap -gravity North-West -append $outfile

#CBS2p4_run-06 SAGITTAL
sequence_name=sub-fMRIPILOT1030_ses-fMRIPILOT1030_task-REST_run-06_acq-CBS2p4_bold
sequence_tag=CBS2p4_run-06
underlay=$OUTPATH_BASE/${sequence_name}/${sequence_name}_skip_mc_tsnr.nii.gz
outfile=$SLICERDIR/${SUB}_${sequence_tag}_BOLD_tsnr_sag.png
filename=$(basename "$underlay")
nmun="${filename%%.*}"
filename3=$(basename "$outfile")
nmout="${filename3%.*}"
zdim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 4 {print}')
xdim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 2 {print}')
ydim=$(fslinfo $underlay | awk '{print $2}' | awk 'FNR == 3 {print}')
numslices=$(($xdim/28))
xthick=$(($xdim-15))
width=$((7*$ydim))
fslroi $underlay ${WKDIR}/ov_roi.nii.gz 15 $xthick 0 $ydim 0 $zdim
fslswapdim ${WKDIR}/ov_roi.nii.gz y z -x ${WKDIR}/${nmov}
slicer ${WKDIR}/${nmov} -l $FSLDIR/etc/luts/render3.lut -i 0 100 -u -S $numslices $width $outfile
convert $outfile -resize 700 $outfile
convert $outfile -background White -pointsize 20 label:$nmout +swap -gravity North-West -append $outfile


#Combine tables across runs to make session QC page
#paste -d , input1.csv input2.csv > combined.csv

### END QC
