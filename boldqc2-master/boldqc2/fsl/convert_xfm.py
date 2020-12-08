import os
import sys
import logging
import pylib.fun as fun
from .. import commons

logger = logging.getLogger(__name__)
this = sys.modules[__name__]

def get(version):
    return commons.get(this, "convert_xfm", version)

def convert_xfm_342e312e37(input, output, **kwargs):
    '''
    Manipulate transformation matrix
    '''
    convert_xfm = fun.which("convert_xfm")
    if not convert_xfm:
        raise commons.CommandNotFoundError("could not find convert_xfm")
    input,output = str(input), str(output)
    cmd = [convert_xfm, "-omat", output]
    if "invert" in kwargs and kwargs["invert"]:
        cmd.append("-inverse")
    cmd.append(input)
    cwd = os.getcwd()
    tic = time.time()
    fun.execute(cmd, kill=True)
    toc = time.time()
    if not os.path.exists(output): 
        raise commons.SubprocessError(cmd)
    provenance = commons.provenance(convert_xfm, cmd, cwd, tic, toc)
    return summary,provenance

