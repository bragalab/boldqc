import os
import sys
import time
import logging
from .. import commons
import pylib.fun as fun

logger = logging.getLogger(__name__)
this = sys.modules[__name__]

def get(version):
    return commons.get(this, "bet", version)

def bet_342e312e37(input, output, **kwargs):
    '''
    FSL v4.0.3 Brain Extraction Tool
    '''
    bet = fun.which(bet)
    if not bet:
        raise commons.CommandNotFoundError("could not find bet")
    input,output = str(input),str(output)
    cmd = [bet, input, output]
    if "vertical_gradient" in kwargs:
        cmd.extend(["-g", str(kwargs["vertical_gradient"])])
    cwd = os.getcwd()
    tic = time.time()
    summary = fun.execute(cmd, kill=True)
    toc = time.time()
    if not os.path.exists(output):
        raise commons.SubprocessError(cmd)
    provenance = commons.provenance(bet, cmd, cwd, tic, toc)
    return summary,provenance

