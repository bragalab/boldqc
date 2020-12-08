import os
import sys
import time
import logging
import pylib.fun as fun
from .. import commons

logger = logging.getLogger(__name__)
this = sys.modules[__name__]

def get(version):
    return commons.get(this, "stackcheck_ext", version)

def stackcheck_ext_312e30(input, output, skip, mask_threshold, experiment, 
                          scan):
    '''
    Produce *extended* motion correction metrics.
    '''
    stackcheck_ext = fun.which("stackcheck_ext.sh")
    if not stackcheck_ext:
        raise commons.CommandNotFoundError("could not find stackcheck_ext.sh")
    input,output = str(input),str(output)
    logger.info(experiment)
    if not os.path.exists(output):
        os.makedirs(output,2755)
    cmd = [stackcheck_ext,
           "-p", "-M", "-T", "-X",
           "-f", input,
           "-o", output,
           "-s", str(skip),
           "-N", str(scan),
           "-t", str(mask_threshold)]
    try:
        if experiment.id:
           cmd.extend(["-S", str(experiment.id)])
    except AttributeError:
        logger.debug('experiment has no id attribute but this is an optional argument to stackcheck.sh, continuing without it.')
        
    if experiment.project:
        cmd.extend(["-P", str(experiment.project)])
    cwd = os.getcwd()
    tic = time.time()
    summary = fun.execute(cmd, kill=True)
    toc = time.time()
    if not os.path.exists(output):
        raise commons.SubprocessError(cmd)
    provenance = commons.provenance(stackcheck_ext, cmd, cwd, tic, toc)
    return summary,provenance

