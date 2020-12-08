#!/bin/bash
#SBATCH --account=b1134                 # Our account/allocation
#SBATCH --partition=buyin-dev               # 'Buyin' submits to our node qhimem0018
#SBATCH --time=00:10:00                 # Walltime/duration of the job
#SBATCH -N 1
#SBATCH -n 1
#SBATCH --mem=8GB                      # Memory per node in GB. Also see --mem-per-cpu
#SBATCH --job-name="test-convert"             # Name of job


module purge all
module load ImageMagick/7.0.4
module load ghostscript/9.19

convert sub-fMRIPILOT1110_ses-fMRIPILOT1110_task-REST01_acq-CBS1p5_bold_skip_mc_rot.png -crop 653x166+25+0 sub-fMRIPILOT1110_ses-fMRIPILOT1110_task-REST01_acq-CBS1p5_bold_skip_mc_rot-Scotty.png
