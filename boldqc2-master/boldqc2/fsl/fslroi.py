import os
import sys
import time
import logging
import nibabel as nib
from .. import commons
import pylib.fun as fun

logger = logging.getLogger(__name__)
this = sys.modules[__name__]

def get(version):
    return commons.get(this, "fslroi", version)

def fslroi_342e312e37(input, output, **kwargs):
    '''
    FSL region of interest utility. 

    Important: Assumes input image shape is x/y/z/t.
    '''
    fslroi = fun.which("fslroi")
    if not fslroi:
        raise commons.CommandNotFoundError("could not find fslroi")
    input,output = str(input), str(output)
    # get image dimensions
    img = nib.load(input)
    x,y,z,t = img.shape
    # build command
    cmd = [fslroi, input, output]
    if "xmin" in kwargs:
        cmd.append(str(kwargs["xmin"]))
    else:
        cmd.append('0')
    if "xsize" in kwargs:
        cmd.append(str(kwargs["xsize"]))
    else:
        cmd.append(str(x))
    if "ymin" in kwargs:
        cmd.append(str(kwargs["ymin"]))
    else:
        cmd.append('0')
    if "ysize" in kwargs:
        cmd.append(str(kwargs["ysize"]))
    else:
        cmd.append(str(y))
    if "zmin" in kwargs:
        cmd.append(str(kwargs["zmin"]))
    else:
        cmd.append('0')
    if "zsize" in kwargs:
        cmd.append(str(kwargs["zsize"]))
    else:
        cmd.append(str(z))
    if "tmin" in kwargs:
        cmd.append(str(kwargs["tmin"]))
    else:
        cmd.append('0')
    if "tsize" in kwargs:
        cmd.append(str(kwargs["tsize"]))
    else:
        cmd.append(str(t))
    # execute command
    cwd = os.getcwd()
    tic = time.time()
    fun.execute(cmd, kill=True)
    toc = time.time()
    if not os.path.exists(output):
        raise commons.SubprocessError(cmd)
    provenance = commons.provenance(fslroi, cmd, cwd, tic, toc)
    return summary,provenance

