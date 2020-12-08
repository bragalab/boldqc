import os
import pylib.fun as fun

class Format:
    ANALYZE = ".analyze"
    NIFTI = ".nii"
    NIFTI_GZ = ".nii.gz"
    DICOM = ""
    MATRIX = ".mat"

class File(object):
    def __init__(self, dirname, basename, format):
        self.dirname = dirname
        if basename.endswith(format):
            basename = basename.rstrip(format)
        self.basename = basename
        self.format = format
        self.fullfile = os.path.join(dirname, basename + format)
        self.multipart = False

    def index(self):
        return None

    def exists(self):
        return os.path.exists(self.fullfile)

    def __str__(self):
        return self.fullfile

class Multipart(File):
    def __init__(self, dirname, basename, format):
        super(Multipart, self).__init__(dirname, basename, format)
        self.multipart = True

    def index(self):
        files = os.listdir(self.fullfile)
        return [os.path.join(self.fullfile, x) for x in files]

class Matrix(File):
    def __init__(self, dirname, basename):
        super(Matrix, self).__init__(dirname, basename, Format.MATRIX)
    
class Analyze(Multipart):
    def __init__(self, dirname, basename):
        super(Analyze, self).__init__(dirname, basename, Format.ANALYZE)
   
class Dicom(Multipart):
    def __init__(self, dirname, basename):
        super(Dicom, self).__init__(dirname, basename, Format.DICOM)

class Nifti(File):
    def __init__(self, dirname, basename):
        super(Nifti, self).__init__(dirname, basename, Format.NIFTI)

class NiftiGz(File):
    def __init__(self, dirname, basename):
        super(NiftiGz, self).__init__(dirname, basename, Format.NIFTI_GZ)

