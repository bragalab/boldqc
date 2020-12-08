#!/bin/bash
#SBATCH --account=b1134                # Our account/allocation
#SBATCH --partition=buyin      		# 'Buyin' submits to our node qhimem0018
#SBATCH --time=00:20:00             # Walltime/duration of the job
#SBATCH --mem=40               # Memory per node in GB. Also see --mem-per-cpu
#SBATCH --output=/projects/b1134/processed/slicer/logs/slcr_CBS1p5_%a_%A.out
#SBATCH --error=/projects/b1134/processed/slicer/logs/slcr_CBS1p5_%a_%A.err
#SBATCH --job-name="Slicer"       # Name of job

# Braga Lab QC Report Script
# Used to output QC report in PDF form

# Created by A. Holubecki - Nov 12th, 2020
 
# Usage:
# slicer_boldqc_CBS1p5.sh scan_name out_dir
# e.g. sh /projects/b1134/tools/boldqc_report/boldqc_report.sh sub-fMRIPILOT1030_ses-fMRIPILOT1030_task-REST01_acq-CBS1p5_bold /projects/b1134/processed/boldqc/SeqDev/sub-fMRIPILOT1030/ses-fMRIPILOT1030/task-REST01

img_name=$1
OUTPATH=$2

if [ ! -e $OUTPATH ]; then
echo "Directory not found: $OUTPATH"
exit
fi

echo "Generating QC report for $img_name"
echo "output directory: $OUTPATH"

mkdir -p $OUTPATH

WKDIR=$OUTPATH/tmp
mkdir -p $WKDIR

# Creating image block from slicers and plots

convert $OUTPATH/${img_name}_skip_mc_rot.png $OUTPATH/${img_name}_skip_mc_trans.png $OUTPATH/${img_name}_skip_mc_disp_abs.png $OUTPATH/${img_name}_skip_mc_disp_rel.png -append $OUTPATH/${img_name}_skip_mc_plots.png
convert $OUTPATH/${img_name}_skip_mc_mean_sag.png $OUTPATH/${img_name}_skip_mc_std_sag.png $OUTPATH/${img_name}_skip_mc_tsnr_sag.png -append $OUTPATH/${img_name}_skip_mc_slicers_sag.png
convert $OUTPATH/${img_name}_skip_mc_plots.png -resize x1089 $OUTPATH/${img_name}_skip_mc_plots.png
convert $OUTPATH/${img_name}_skip_mc_plots.png $OUTPATH/${img_name}_skip_mc_slicers_sag.png +append $OUTPATH/${img_name}_skip_mc_images.png
convert $OUTPATH/${img_name}_qcvals.png -resize x1900 $OUTPATH/${img_name}_qcvals.png
convert $OUTPATH/${img_name}_qcvals.png $OUTPATH/${img_name}_skip_mc_images.png -append $OUTPATH/${img_name}_qcreport.png
convert $OUTPATH/${img_name}_qcreport.png -background White -size 1900x80 -pointsize 40 -gravity center label:'sub-fMRIPILOT1110_ses-fMRIPILOT1110_task-REST04_acq-CBS2p4_bold QC Report' +swap -append $OUTPATH/${img_name}_qcreport.png
convert $OUTPATH/${img_name}_qcreport.png -rotate 90 $OUTPATH/${img_name}_qcreport_rotated.png
convert $OUTPATH/${img_name}_qcreport_rotated.png -page A4 $OUTPATH/${img_name}_qcreport.pdf
convert $OUTPATH/${img_name}_qcreport.pdf -rotate -90 $OUTPATH/${img_name}_qcreport.pdf
