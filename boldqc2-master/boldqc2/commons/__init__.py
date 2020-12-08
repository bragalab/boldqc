import os
import sys
import socket
import base64
import hashlib
import getpass as gp
import datetime as dt
import nibabel as nib
import subprocess as sp
import collections as col

Provenance = col.namedtuple("Provenance", ["basename", "dirname", 
                                           "checksum", "command", 
                                           "start", "start_date", 
                                           "start_time", "end", 
                                           "username", "mtime",
                                           "cwd", "os", "hostname", 
                                           "elapsed"])

def provenance(exe, command, cwd, start, end):
    return Provenance(basename=os.path.basename(exe), 
                      dirname=os.path.dirname(exe), 
                      checksum=sha256file(exe), 
                      mtime=dt.datetime.fromtimestamp(os.path.getmtime(exe)).isoformat(), 
                      command=command, 
                      start=start, 
                      end=end, 
                      os=sp.check_output(["uname", "-a"]).strip(), 
                      hostname=socket.gethostname(), 
                      cwd=cwd, 
                      username=gp.getuser(), 
                      start_date=dt.datetime.fromtimestamp(start).strftime("%Y-%m-%d"), 
                      start_time=dt.datetime.fromtimestamp(start).strftime("%H:%M:%S"), 
                      elapsed=end-start)
    
def get(module, name, version):
    hash = base64.b16encode(version).lower()
    fname = "%s_%s" % (name, hash)
    try:
        return getattr(module, fname)
    except ValueError:
        raise VersionError("could not find %s/%s (%s)" % (name, version, fname))

def dimlen(input, dim):
    input = nib.load(input)
    return input.shape[dim]

def sha256file(f):
    f = os.path.expanduser(f)
    with open(f, "rb") as fo:
        return hashlib.sha256(fo.read()).hexdigest()

class Orient:
    NEUROLOGICAL = 0
    RADIOLOGICAL = 1 

class Order:
    ASCEND = 0
    DESCEND = 1
    INTER_MIDDLE_TOP = 2
    INTER_BOTTOM_UP = 3
    INTER_TOP_DOWN = 4

class Axis:
    X = 0
    Y = 1
    Z = 2
    T = 3

class VersionError(Exception):
    pass

class SubprocessError(Exception):
    pass

class APIError(Exception):
    pass

class CommandNotFoundError(Exception):
    pass

