# Braga Lab QC Pipeline
# Created by Ania Holubecki on September 28th, 2020

# PREPARE VARIABLES AND FOLDER FOR MRIQC

projectnm=SeqDev
SUB=fMRIPILOT1030
SESS=fMRIPILOT1030

# datadir=/Users/amh409/Documents/braga_lab/data/$SUB/raw/bids/SeqDev # This is a local directory; will need to update with Braga Lab specific directories once all systems are set up
# qcdir=/Volumes/fsmresfiles/Neurology/Braga_Lab/qc/mri_qc/$SESS # Do not change

# mkdir -p $qcdir

### RUN MRIQC ON DATA

# docker run -it --rm -v ${datadir}:/data:ro -v ${qcdir}:/out poldracklab/mriqc:latest /data /out participant --participant_label fMRIPILOT0923 --hmc-fsl --fd_thres 0.2 --verbose-reports --verbose

# docker run -it --rm -v ${datadir}:/data:ro -v ${qcdir}:/out poldracklab/mriqc:latest /data /out group --verbose-reports --verbose

### PREPARE VARIABLES AND FOLDER FOR QC 

SCAN=sub-fMRIPILOT1030_ses-fMRIPILOT1030_task-REST_run-01_acq-CBS1p5_bold
SCAN=sub-fMRIPILOT1030_ses-fMRIPILOT1030_task-REST_run-02_acq-CBS2p4_bold
SCAN=sub-fMRIPILOT1030_ses-fMRIPILOT1030_task-REST_run-03_acq-CBS1p5_bold
SCAN=sub-fMRIPILOT1030_ses-fMRIPILOT1030_task-REST_run-04_acq-CBS2p4_bold
SCAN=sub-fMRIPILOT1030_ses-fMRIPILOT1030_task-REST_run-05_acq-CBS1p5_bold
SCAN=sub-fMRIPILOT1030_ses-fMRIPILOT1030_task-REST_run-06_acq-CBS2p4_bold


# These are local directories; will need to update with Braga Lab specific directories once all systems are set up
BASEDIR=/Users/sec9607/Documents/braga_lab/data/$SUB/raw/bids/SeqDev/sub-${SUB}/ses-${SESS} #base diretory for your raw data
DATAPATH=$BASEDIR/func
OUTPATH=/Users/sec9607/Documents/MRI_data/sub-${SUB}/ses-${SESS}/preproc_func/$SCAN

mkdir -p $OUTPATH
cd $OUTPATH

### SKIPPING FIRST 4 VOLUMES

totpts=$(fslinfo $DATAPATH/$SCAN | awk '{print $2}' | awk 'FNR == 5 {print}')
echo $totpts #make sure this is equal to the number of frames in the scan
numpts=$(($totpts-4))

echo 'Skipping first 4 volumes'
fslroi $DATAPATH/${SCAN} $OUTPATH/${SCAN}_skip 4 $numpts

### PERFORMING MOTION CORRECTION

echo 'Performing motion correction'
mcflirt -in $OUTPATH/${SCAN}_skip -out $OUTPATH/${SCAN}_skip_mc -mats -refvol 0 -plots -rmsrel -rmsabs -report

# CREATING MCFLIRT PLOTS

rot="0.010"
ymin_rot=$(bc<<<"0-$rot")
ymax_rot=$(bc<<<"0+$rot")

fsl_tsplot -i $OUTPATH/${SCAN}_skip_mc.par -t 'MCFLIRT estimated rotations (radians)' -u 1 --start=1 --finish=3 --ymin=$ymin_rot --ymax=$ymax_rot -a x,y,z -w 640 -h 144 -o $OUTPATH/${SCAN}_skip_mc_rot.png

trans="1"
ymin_trans=$(bc<<<"0-$trans")
ymax_trans=$(bc<<<"0+$trans")

fsl_tsplot -i $OUTPATH/${SCAN}_skip_mc.par -t 'MCFLIRT estimated translations (mm)' -u 1 --start=4 --finish=6 --ymin=$ymin_trans --ymax=$ymax_trans -a x,y,z -w 640 -h 144 -o $OUTPATH/${SCAN}_skip_mc_trans.png

fsl_tsplot -i $OUTPATH/${SCAN}_skip_mc_abs.rms,$OUTPATH/${SCAN}_skip_mc_rel.rms -t 'MCFLIRT estimated mean displacement (mm)' -u 1 -w 640 -h 144 -a absolute,relative -o $OUTPATH/${SCAN}_skip_mc_disp.png

fsl_tsplot -i $OUTPATH/${SCAN}_skip_mc_rel.rms -t 'MCFLIRT estimated relative mean displacement (mm)' -u 1 --ymin=0 --ymax=1 -w 640 -h 144 -o $OUTPATH/${SCAN}_skip_mc_disp_rel.png

fsl_tsplot -i $OUTPATH/${SCAN}_skip_mc_abs.rms, -t 'MCFLIRT estimated absolute mean displacement (mm)' -u 1 --ymin=0 --ymax=1 -w 640 -h 144 -o $OUTPATH/${SCAN}_skip_mc_disp_abs.png

### CALCULATIONS

echo 'Calculating max framewise displacement'
cat $OUTPATH/${SCAN}_skip_mc_rel.rms | sort -n | tail -1

echo 'Calculating mean framewise displacement'
cat $OUTPATH/${SCAN}_skip_mc_rel_mean.rms

echo 'Calculating max motion'
cat $OUTPATH/${SCAN}_skip_mc_abs.rms | sort -n | tail -1

echo 'Calculating FD > 0.2; count the values'
cat $OUTPATH/${SCAN}_skip_mc_rel.rms | sort -n

### MEAN, STD, TSNR

echo 'Calculating mean and std image'
fslmaths $OUTPATH/${SCAN}_skip_mc -Tmean $OUTPATH/${SCAN}_skip_mc_mean
fslmaths $OUTPATH/${SCAN}_skip_mc -Tstd $OUTPATH/${SCAN}_skip_mc_std

echo 'Creating tSNR image'
fslmaths $OUTPATH/${SCAN}_skip_mc_mean -div $OUTPATH/${SCAN}_skip_mc_std $OUTPATH/${SCAN}_skip_mc_tsnr

### CALCULATIONS

echo 'Calculating voxel tSNR'
fslstats $OUTPATH/${SCAN}_skip_mc_tsnr -m 

echo 'Calculating mean BOLD' #eav only for ME
fslstats $OUTPATH/${SCAN}_skip_mc_mean -M 

echo 'Calculating mean STD BOLD' #eav only for ME
fslstats $OUTPATH/${SCAN}_skip_mc_std -M

### REPEAT ENTIRE ABOVE FOR ALL SCANS; MAKE SURE YOU REDEFINE OUTPATH EACH TIME

### SAM STOP HERE

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




### END QC
