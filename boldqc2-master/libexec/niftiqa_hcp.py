#!/usr/bin/env python

import os
import sys
import glob
import math
import atexit
import logging
import argparse
import tempfile
import nibabel as nib
import pylib.fun as fun

logger = logging.getLogger(os.path.basename(__file__))
logging.basicConfig(level=logging.INFO)

# default path to niftiqa executable
DIR = os.path.dirname(__file__)
LIBEXEC = fun.expand(os.path.join(DIR, "..", "libexec"))
NIFTIQA = os.path.join(LIBEXEC, "niftiqa.py")

def main():
    parser = argparse.ArgumentParser(description="Run niftiqa on a HCP NIfTI-1 image")
    parser.add_argument("-o", "--output-dir", 
        help="Output directory")
    parser.add_argument("-S", "--scratch-dir",
        help="Scratch directory")
    parser.add_argument("-s", "--skip", type=int, default=6,
        help="Number of volumes to skip")
    parser.add_argument("-m", "--mask-threshold", type=float, default=200.0,
        help="Masking threshold")
    parser.add_argument("--snr-pct", type=float, default=0.5,
        help="Percent intensity for SNR image")
    parser.add_argument("-x", "--snap-x", type=int, default=8,
        help="Snapshot image width (in slices)")
    parser.add_argument("-y", "--snap-y", type=int, default=None,
        help="Snapshot image height (in slices)")
    parser.add_argument("--niftiqa", default=NIFTIQA,
        help="Path to niftiqa executable")
    parser.add_argument("-d", "--debug", action="store_true",
        help="Enable debug messages")
    parser.add_argument("image",
        help="NIfTI-1 image")
    args = parser.parse_args()
    
    # enable debug messages
    if args.debug:
        logger.setLevel(logging.DEBUG)
        logging.getLogger("pylib.fun").setLevel(logging.DEBUG)
    
    # check input image
    args.image = fun.expand(args.image)
    if not os.path.exists(args.image):
        logger.critical("input image does not exist: %s", args.image)
        sys.exit(1)
    base,ext = fun.splitext(os.path.basename(args.image))
    logger.info("file base=%s, ext=%s", base, ext)

    # use scratch directory as the base output directory, rename on exit
    args.output_dir = fun.expand(args.output_dir)
    output_dir = args.output_dir
    if args.scratch_dir:
        args.scratch_dir = fun.expand(args.scratch_dir)
        output_dir = tempfile.mkdtemp(dir=args.scratch_dir, prefix="extqc_")
        atexit.register(fun.cleanup, output_dir, args.output_dir)
        logger.info("working directory=%s, output directory=%s", output_dir,
            args.output_dir)
    
    # run niftiqa script
    logger.info("running niftiqa command on %s", args.image)
    eqcdir = os.path.join(output_dir)
    niftiqa(args.image, eqcdir, skip=args.skip, mask_threshold=args.mask_threshold)
    
    # niftiqa wasn't supposed to save out any images unless you asked it to
    logger.info("removing .png, .svg, and .html files from niftiqa output")
    for pattern in ["*.png", "*.svg", "*.html"]:
        for f in glob.glob(os.path.join(eqcdir, pattern)):
            if not f.endswith("mean_slice.png"):
                logger.info("removing %s", f)
                os.remove(f)
    
    # generate new snapshots
    os.chdir(eqcdir)
    mosaic("%s_mask%s" % (base, ext), "%s_mask_thumbnail.png" % base,
        xy=(args.snap_x, args.snap_y))
    mosaic("%s_mean%s" % (base, ext), "%s_mean_thumbnail.png" % base,
        xy=(args.snap_x, args.snap_y))
    mosaic("%s_stdev%s" % (base, ext), "%s_stdev_thumbnail.png" % base,
        xy=(args.snap_x, args.snap_y))
    mosaic("%s_slope%s" % (base, ext), "%s_slope_thumbnail.png" % base,
        xy=(args.snap_x, args.snap_y))
    mosaic("%s_snr%s" % (base, ext), "%s_snr_thumbnail.png" % base,
        xy=(args.snap_x, args.snap_y), win=(0, args.snr_pct))

    # done
    logger.info("finished")

def mosaic(inp, output, xy, win=None):
    '''
    Take snapshot of NIfTI-1 3D image

    :param inp: inp file
    :type inp: str
    :param output: Output file
    :type output: str
    :param xy: Snapshot image X and Y lengths, in slices
    :type xy: tuple
    :param win: Window of voxel intensity
    :type win: tuple
    '''
    if win and len(win) != 2:
        raise MosaicError("window argument must be (a,b)")
    nii = nib.load(inp)
    x,y,z = nii.shape
    logger.debug("x=%s, y=%s, z=%s", x, y, z)
    # get snapshot image x length (in numbers of voxels)
    x_width = x * xy[0]
    # determine if we need a subset of slices to fit the desired y length
    nth_vox = 1
    if xy[1]:
        nth_vox = math.ceil(float(z) / (xy[0] * xy[1]))
    # read the image data payload
    niid = nii.get_data()
    niid_min, niid_max = niid.min(), niid.max()
    logger.debug("image=%s, min=%s, max=%s", inp, niid_min, niid_max)
    # the order of arguments is important
    com = ["slicer", inp]
    if win:
        com.extend(["-i", str(win[0] * niid_min), str(win[1] * niid_max)])
    com.extend(["-u", "-S", str(nth_vox), str(x_width), output])
    fun.execute(com, kill=True)

class MosaicError(Exception):
    pass

def niftiqa(niifile, output_dir, skip=4, mask_threshold=200.0, exe=NIFTIQA):
    '''
    Run standard niftiqa script
    '''
    if not os.path.exists(output_dir):
        os.makedirs(output_dir,2755)
    com = [exe, "--skip", str(skip), "--mask-threshold", str(mask_threshold), 
        "--mean-slice-plot-format" ,"png", "--all", "--output-dir", output_dir, 
        niifile]
    fun.execute(com, kill=True)

if __name__ == "__main__":
    main()

