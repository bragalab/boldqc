import os
import sys
import time
import logging
import pylib.fun as fun
from .. import commons

logger = logging.getLogger(__name__)
this = sys.modules[__name__]

def get(version):
    return commons.get(this, "niftiqa", version)

def niftiqa_312e30(input, output, skip, mask_threshold, snap=(None, None)):
    '''
    Produce QA data for a NIfTI-1 file.
    '''
    niftiqa = fun.which("niftiqa_hcp.py")
    if not niftiqa:
        raise commons.CommandNotFoundError("could not find niftiqa_hcp.py")
    input,output = str(input),str(output)
    if not os.path.exists(output):
        os.makedirs(output)
    cmd = [niftiqa, 
           "--output-dir", output,
           "--skip", str(skip), 
           "--mask-threshold", str(mask_threshold), 
           "--debug"]
    if snap[0] is not None:
        cmd.extend(["--snap-x", str(snap[0])])
    if snap[1] is not None:
        cmd.extend(["--snap-y", str(snap[1])])
    cmd.append(input)
    cwd = os.getcwd()
    tic = time.time()
    summary = fun.execute(cmd, kill=True)
    toc = time.time()
    if not os.path.exists(output):
        raise commons.SubprocessError(cmd)
    provenance = commons.provenance(niftiqa, cmd, cwd, tic, toc)
    return summary,provenance

