import os
import sys
import time
import logging
from .. import commons
import pylib.fun as fun

logger = logging.getLogger(__name__)
this = sys.modules[__name__]

def get(version):
    return commons.get(this, "fslswapdim", version)

def fslswapdim_342e312e37(input, output, rule):
    '''
    Swap dimensions of input file
    '''
    fslswapdim = fun.which("fslswapdim")
    if not fslswapdim:
        raise commons.CommandNotFoundError("could not find fslswapdim")
    input, output = str(input), str(output)
    cmd = [fslswapdim, input] + rule + [output]
    cwd = os.getcwd()
    tic = time.time()
    summary = fun.execute(cmd, kill=True)
    toc = time.time()
    if not os.path.exists(output):
        raise commons.SubprocessError(cmd)
    provenance = commons.provenance(fslswapdim, cmd, cwd, tic, toc)
    return summary,provenance

