import os
import sys
import time
import shutil
import logging
import pylib.fun as fun
from .. import commons

logger = logging.getLogger(__name__)
this = sys.modules[__name__]

def get(version):
    return commons.get(this, "fslorient", version)

def fslorient_342e312e37(input, output, orientation):
    '''
    Reorient file
    '''
    fslorient = fun.which("fslorient")
    if not fslorient:
        raise commons.CommandNotFoundError("could not find fslorient")
    input,output = str(input), str(output)
    # fslorient will overwrite the input file
    if fun.expand(input) != fun.expand(output):
        shutil.copy(input, output)
    else:
        output = input
    # get the desired orientation as a string
    if orientation == commons.Orient.NEUROLOGICAL:
        orientation = 'NEUROLOGICAL'
    elif orientation == commons.Orient.RADIOLOGICAL:
        orientation = 'RADIOLOGICAL'
    # get the current orientation of the file
    cmd = ["fslorient", "-getorient", input]
    summary = fun.execute(cmd)
    try:
      current_orientation = summary.stdout.strip().upper()
    except:
      logger.warning(summary)
      raise
    # return now if the file is already in the desired orientation
    if current_orientation == orientation:
        return
    # swap the orientation
    cmd = [fslorient, "-swaporient", output]
    cwd = os.getcwd()
    tic = time.time()
    fun.execute(cmd, kill=True)
    toc = time.time()
    if not os.path.exists(output):
        raise commons.SubprocessError(cmd)
    provenance = commons.provenance(fslorient, cmd, cwd, tic, toc)
    return summary, provenance

