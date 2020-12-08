import os
import sys
import time
import logging
from .. import commons
import pylib.fun as fun

logger = logging.getLogger(__name__)
this = sys.modules[__name__]

def get(version):
    return commons.get(this, "fslmerge", version)

def fslmerge_342e312e37(input, output, **kwargs):
    '''
    FSL v4.0.3 merge tool
    '''
    fslmerge = fun.which("fslmerge")
    if not fslmerge:
        raise commons.CommandNotFoundError("could not find fslmerge")
    output = str(output)
    cmd = ["fslmerge"]
    if "axis" in kwargs:
        if kwargs["axis"] == commons.Axis.X:
            cmd.append("-x")
        elif kwargs["axis"] == commons.Axis.Y:
            cmd.append("-y")
        elif kwargs["axis"] == commons.Axis.Z:
            cmd.append("-z")
        elif kwargs["axis"] == commons.Axis.T:
            cmd.append("-t")
    else:
        raise commons.APIError("axis argument required")
    cmd.append(output)
    cmd.extend(input)
    cwd = os.getcwd()
    tic = time.time()
    fun.execute(cmd, kill=True)
    toc = time.time()
    if not os.path.exists(output):
        raise commons.SubprocessError(cmd)
    provenance = commons.provenance(fslmerge, cmd, cwd, tic, toc)
    return summary,provenance

