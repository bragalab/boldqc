import os
import sys
import time
import logging
from .. import commons
import pylib.fun as fun

logger = logging.getLogger(__name__)
this = sys.modules[__name__]

def get(version):
    return commons.get(this, "mri_convert", version)

def mri_convert_323031355f31325f3033(infile, outfile, **kwargs):
    '''
    Greve mri_convert/2015_11_09 file converter
    '''
    mri_convert = fun.which("mri_convert")
    if not mri_convert:
        raise commons.CommandNotFoundError("could not find mri_convert")
    infile, outfile = str(infile), str(outfile)
    d = os.path.dirname(outfile)
    if not os.path.exists(d):
        os.makedirs(d)
    cmd = [mri_convert, infile]
    if "outtype" in kwargs:
        cmd.extend(["-ot", kwargs["outtype"]])
    cmd.append(outfile)
    cwd = os.getcwd()
    tic = time.time()
    summary = fun.execute(cmd, kill=True)
    toc = time.time()
    provenance = commons.provenance(mri_convert, cmd, cwd, tic, toc)
    return summary,provenance

