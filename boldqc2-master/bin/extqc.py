#!/usr/bin/env python
''' to test:
extqc.py --label test_eyetracker --project scantest --scan 10 --skip 4 --mask-threshold 150 --snap-x 8 --snap-y 6 --output-dir /tmp/singularity-bootstrap/pipelineOut --xnat cbscentral
'''
import shlex
import datetime
import os
import sys
import time
import socket
import shutil
import logging
import dicom
import hashlib
import boldqc2.xnat 
import getpass as gp
import nibabel as nib
import datetime as dt
import argparse as ap
import lxml.etree as et
import subprocess as sp
import pylib.fun as fun
import pylib.xnat as xnat
import boldqc2.fsl as fsl
import boldqc2.eqc as eqc
import pylib.brains as brains
import boldqc2.greve as greve
import boldqc2.formats as formats
import boldqc2.commons as commons

logger = logging.getLogger(os.path.basename(__file__))
logging.basicConfig(level=logging.INFO)

DIR = os.path.dirname(__file__)
LIBEXEC = os.path.realpath(os.path.join(DIR, "..", "libexec"))
Version = fun.Namespace(FSL="4.1.7", Greve="2015_12_03",
                        EQC="1.0")

def main():
    parser = ap.ArgumentParser(description="ExtendedBOLDQC pipeline")
    parser.add_argument("-x", "--xnat", 
        help="XNAT alias")
    parser.add_argument("-u", "--upload", action="store_true",
        help="Upload XAR to XNAT")
    parser.add_argument("-l", "--label", required=True, 
        help="MR Session Label")
    parser.add_argument("-p", "--project",
        help="MR Session Project")
    parser.add_argument("-s", "--scan", type=int, required=True, 
        help="Scan ID")
    parser.add_argument("--mask-threshold", type=float, 
        help="Masking threshold")
    parser.add_argument("--skip", type=int, default=4, 
       help="Skip volumes")
    parser.add_argument("--snap-x", type=int, default=8,
        help="Snap output image to X slices per row")
    parser.add_argument("--snap-y", type=int, default=None,
        help="Snap output image to Y slices per column")
    parser.add_argument("-d", "--input-dicom", 
        help="Input DICOM")
    parser.add_argument("-n", "--input-nifti", 
        help="Input NIFTI-1 file")
    parser.add_argument("-o", "--output-dir", default='.', 
        help="Output directory")
    parser.add_argument("--debug", action="store_true", 
        help="Enable debug messages")
    parser.add_argument("--overwrite", action="store_true", 
        help="Overwrite existing output")
    parser.add_argument("--keep-dicoms", action="store_true", 
        help="save dicom working directory as dicoms, instead of replacing with sha256 sums, which is the default behavior.")
    args = parser.parse_args()

    # start time
    tic = time.time()

    # enable debug messages
    if args.debug:
        logging.getLogger("pylib.fun").setLevel(logging.DEBUG)
        logging.getLogger("pylib.xnat").setLevel(logging.DEBUG)
        logging.getLogger("pylib.brains").setLevel(logging.DEBUG)
        logger.setLevel(logging.DEBUG)

    # catch any mutually inclusive argument errors here
    if args.upload and not args.xnat:
        logger.critical("--upload and --xnat are inclusive")
        sys.exit(1)

    # prepend libexec to PATH environment variable
    os.environ["PATH"] = LIBEXEC + os.pathsep + os.environ["PATH"]

    # tuple of experiment project and label (query xnat if possible)
    experiment = fun.Namespace(project=args.project, label=args.label)
    if args.xnat:
        a = xnat.auth(args.xnat)
        experiment = xnat.experiment(a, args.label, args.project)
    logger.info(experiment)

    # output directory
    outdir = fun.expand(args.output_dir)

    # scrub old failures
    if args.overwrite:
        if os.path.exists(outdir):
            s = os.stat(outdir)
            cutoff = time.time() - (60*60*24)
            if s.st_mtime > cutoff :
                #less than a day old, delete
                shutil.rmtree(outdir)
                os.mkdir(outdir)
            else:
                outdir_contents = os.listdir(outdir)
                if any(x in outdir_contents for x in ['dicom', 'extended-qc', 'nifti']):
                    logger.info('previous directory contents found:')
                    logger.info(outdir_contents)
                    os.rename(outdir, '{DIR}-old-{DATETIME}'.format(DIR=outdir, DATETIME=datetime.datetime.now().isoformat()))
        
    # initialize list to hold subprocess provenance information
    provenance = []

    # get mri_convert function interface
    mri_convert = greve.mri_convert.get(Version.Greve)

    '''
    User specified NIfTI-1 file? yes -> use it
      no
      |
      v
    User specified a DICOM directory? yes -> use it
      no
      |
      v
    Download files from XNAT
    '''
    if not args.input_nifti:
        # download files from xnat
        if not args.input_dicom:
            if not args.xnat:
                logger.critical("must provide --xnat to download scan files")
                sys.exit(1)
            # build dicom output file name
            dirname,basename = os.path.join(args.output_dir, "dicom"), str(args.scan)
            args.input_dicom = formats.Dicom(dirname, basename)
            logger.info("downloading session=%s, scan=%s, destination=%s" % (args.label,
                        args.scan, args.input_dicom))
            download(args.xnat, args.label, args.project, [args.scan],
                     args.input_dicom)
        else:
            dirname = os.path.dirname(args.input_dicom)
            basename = os.path.basename(args.input_dicom)
            args.input_dicom = formats.Dicom(dirname, basename)
        # build nifti output file name
        dirname =  os.path.join(outdir, "nifti", "%d" % args.scan)
        basename = "%s_BOLD_%d_EQC" % (args.label, args.scan)
        args.input_nifti = formats.NiftiGz(dirname, basename)
        # convert dicom files to nifti
        logger.info("converting %s to %s" % (args.input_dicom, args.input_nifti))
        _samplefile = sample_dicom(args.input_dicom.fullfile)
        if not args.mask_threshold:
            args.mask_threshold = auto_mask(_samplefile)
            logger.info("mask automatically set to {}".format(args.mask_threshold))
        else:
            logger.info("user-defined mask set to {}".format(args.mask_threshold))
        _,p = mri_convert(_samplefile, args.input_nifti)
        provenance.append(p)
    else:
        args.input_nifti = fun.expand(args.input_nifti)
        if not os.path.exists(args.input_nifti):
            logger.critical("nifti file not found %s" % args.input_nifti)
            sys.exit(1)
        dirname = os.path.dirname(args.input_nifti)
        basename = os.path.basename(args.input_nifti)
        if basename.endswith(".gz"):
            args.input_nifti = formats.NiftiGz(dirname, basename)
        else:
            args.input_nifti = formats.Nifti(dirname, basename)
    logger.info("scan %s nifti file is %s" % (args.scan, args.input_nifti))
   
    # get masking threshold
    if not args.mask_threshold:
        args.mask_threshold = maskthreshold(args.input_nifti)
        logger.info("choosing masking threshold {} based on maximum voxel intensity".format(args.mask_threshold))
    logger.info("using a masking threshold of %s", args.mask_threshold)

    # run reorientation pipeline
    logger.info("reorienting nifti file %s" % args.input_nifti)
    p = reorient_pipeline(args.input_nifti, args.input_nifti, ["RL", "PA", "IS"],
                          commons.Orient.RADIOLOGICAL)
    provenance.extend(p)

    # run niftiqa pipeline
    eqc_output = os.path.join(args.output_dir, "extended-qc")
    logger.info("computing extendedboldqc %s", eqc_output)
    p = boldqc_pipeline(args.input_nifti, eqc_output, args.skip, 
                        args.mask_threshold, (args.snap_x, args.snap_y),
                        experiment, args.scan)
    provenance.extend(p)
    
    if not args.keep_dicoms:
        outdir_contents = os.listdir(outdir)
        if 'dicom' in outdir_contents:
            dicom_scans = os.listdir(os.path.join(outdir, 'dicom'))
            for scan in dicom_scans:
                dicoms = os.listdir(os.path.join(outdir, 'dicom', scan))
                dicoms_full_path = [os.path.join(outdir,'dicom', scan, f) for f in dicoms]
                for file in dicoms_full_path:
                    hash(file)

    # initialize list to hold subprocess provenance information
    provenance = []

    # end
    toc = time.time()

    # generate xar file for xnat
    if args.xnat:
        label = "{0}_BOLD_{1}_EQC".format(args.label, args.scan)
        exe = os.path.abspath(os.path.expanduser(sys.argv[0]))
        state = fun.Namespace(runtime=toc-tic,
                              start_date=dt.datetime.fromtimestamp(tic).strftime("%Y-%m-%d"),
                              start_time=dt.datetime.fromtimestamp(tic).strftime("%H:%M:%S"),
                              username=gp.getuser(),
                              initial_cwd=os.getcwd(),
                              command=sys.argv,
                              os=sp.check_output(["uname", "-a"]).strip(),
                              hostname=socket.gethostname(),
                              exe=exe,
                              checksum=commons.sha256file(exe),
                              mtime=dt.datetime.fromtimestamp(os.path.getmtime(exe)).isoformat(),
                              provenance=provenance)
        xarfile = os.path.join(args.output_dir, "xar.zip")
        logger.info("generating xar file %s" % xarfile)
        boldqc2.xnat.xar(args.output_dir, experiment.project, label, experiment.id, args.scan, 
                        state, xarfile)

    # upload xar to xnat
    if args.upload:
        auth = xnat.auth(args.xnat)
        xarfile = os.path.join(args.output_dir, "xar.zip")
        if not os.path.exists(xarfile):
            raise Exception("file does not exist %s" % xarfile)
        xnat.storexar(auth, xarfile)

def hash(file): 
    hash = hashlib.sha256(open(file, 'rb').read()).digest()
    hash_name = '{}.sha256'.format(file)
    with open(hash_name, 'wb') as f:
        f.write(hash)
    os.remove(file)

def sample_dicom(d):
    '''
    Find a sample DICOM file from a DICOM directory
    '''
    logger.debug("scanning for dicoms within %s" % d)
    scans = brains.search_dicoms(d)
    if len(scans) == 0:
        raise DICOMError("no dicom files found under %s" % d)
    if len(scans) > 1:
        raise DICOMError("multiple dicom studyinstanceuids found under %s" % d)
    _,study = scans.popitem()
    for _,series in iter(study.items()):
        for num,instance in iter(series.items()):
            if len(instance) > 1:
                raise DICOMError("multiple dicom series instance numbers %s" % num) 
            return instance[0].file

class DICOMError(Exception):
    pass

def download(alias, session, project, scans, outdir):
    '''
    Download imaging data from XNAT
    '''
    auth = xnat.auth(alias)
    aid = xnat.accession(auth, session, project)
    xnat.download(auth, aid, scans, str(outdir))

def reorient_pipeline(input, output, axes, orientation):
    '''
    Reorientation pipeline
    '''
    fslswapdim = fsl.fslswapdim.get(Version.FSL)
    fslorient = fsl.fslorient.get(Version.FSL)
    _,p1 = fslorient(input, output, orientation)
    _,p2 = fslswapdim(input, output, axes)
    return p1,p2    

def boldqc_pipeline(input, output, skip, mask_threshold, snap, 
                    experiment, scan):
    '''
    BOLDQC pipeline
    '''
    niftiqa = eqc.niftiqa.get(Version.EQC)
    stackcheck_ext = eqc.stackcheck_ext.get(Version.EQC)
    _,p1 = niftiqa(input, output, skip, mask_threshold, snap)
    _,p2 = stackcheck_ext(input, output, skip, mask_threshold, experiment, scan)
    return p1,p2

def maskthreshold(nii):
    '''
    Automatic mask thresholding for Minnesota sequence Niftis and other SMS
    '''
    logger.warning("Auto-masking based on voxel intensities. This usually works but is not guaranteed.")
    nii = nib.load(str(nii))
    if nii.get_data().max() >= 4096:
        return 3000.0
    return 150.0

def auto_mask(dicom_file):
    '''
    Automatic mask thresholding for Minnesota sequence and other SMS dicoms
    '''
    dcm = dicom.read_file(dicom_file)
    bits_stored = dcm[0x0028,0x0101].value
    # see https://www.jiscmail.ac.uk/cgi-bin/webadmin?A2=spm;55d18572.1103
    dcm_coil = sp.check_output('strings {DCMFILE} | grep tCoilID | head -n 1'.format(DCMFILE=dicom_file), shell=True)
    if "Head_32" in dcm_coil:
        coil = "Head_32"
    elif "Head_64" in dcm_coil:
        coil = "Head_64"
    else: # no known coil type found
        coil = dcm_coil.split('\t')[-1].strip() 
    if (bits_stored == 12):
        return 150.0 
    elif (bits_stored == 16):
        if coil == "Head_32":
            return 1500.0
        elif coil == "Head_64":
            return 3000.0
        else:
            logger.warning('unknown coil: {}. Using 3000.0 threshold.'.format(coil))
            return 3000.0
    else:
        raise UnexpectedBitsError(dicom_file, bits_stored)

class UnexpectedBitsError(Exception):
  pass

if __name__ == "__main__":
    main()

