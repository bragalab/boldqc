import os
import sys
import time
import logging
from .. import commons
import pylib.fun as fun

logger = logging.getLogger(__name__)
this = sys.modules[__name__]

def get(version):
    return commons.get(this, "flirt", version)

def flirt_342e312e37(input, output, **kwargs):
    '''
    Fast linear image registration
    '''
    flirt = fun.which("flirt")
    if not flirt:
        raise commons.CommandNotFoundError("could not find flirt")
    input,output = str(input),str(output)
    cmd = [flirt, "-in", input, "-out", output]
    if "input_matrix" in kwargs:
        cmd.extend(["-init", str(kwargs["input_matrix"])])
    if "output_matrix" in kwargs:
        cmd.extend(["-omat", str(kwargs["output_matrix"])])
    if "reference" in kwargs:
        cmd.extend(["-ref", kwargs["reference"]])
    if "cost" in kwargs:
        cmd.extend(["-cost", kwargs["cost"]])
    if "dof" in kwargs:
        cmd.extend(["-dof", str(kwargs["dof"])])
    if "searchr_x" in kwargs:
        a,b = str(kwargs["searchr_x"][0]),str(kwargs["searchr_x"][1])
        cmd.extend(["-searchrx", a, b])
    if "searchr_y" in kwargs:
        a,b = str(kwargs["searchr_y"][0]),str(kwargs["searchr_y"][1])
        cmd.extend(["-searchry", a, b])
    if "searchr_z" in kwargs:
        a,b = str(kwargs["searchr_z"][0]),str(kwargs["searchr_z"][1])
        cmd.extend(["-searchrz", a, b])
    if "interp" in kwargs:
        cmd.extend(["-interp", kwargs["interp"]])
    if "applyisoxfm" in kwargs:
        cmd.extend(["-applyisoxfm", str(kwargs["applyisoxfm"])])
    if "applyxfm" in kwargs and kwargs["applyxfm"]:
        cmd.append("-applyxfm")
    if "forcescaling" in kwargs:
        cmd.append("-forcescaling")
    cwd = os.getcwd()
    tic = time.time()
    fun.execute(cmd, kill=True)
    toc = time.time()
    if not os.path.exists(output):
        raise commons.SubprocessError(cmd)
    provenance = commons.provenance(flirt, cmd, cwd, tic, toc)
    return summary,provenance

