Extended BOLD Quality Control v2
================================
Tools for computing quality assessment of BOLD imaging data.

## Table of contents
1. [Requirements](#requirements)
2. [Usage](#usage)
3. [Singularity](#singularity)

## Requirements
The following software is required

* Python 2.7+
* FreeSurfer 5.3.0+
* FSL 4.1.7+

## Usage
If you have DICOM files on disk, supply the `--input-dicom` argument

```bash
extqc.py --xnat=nrgcentral --label=AB1234C --scan=3 --input-dicom=/path/to/dicoms
```

If you need to download DICOM files from XNAT, supply the `--xnat` argument

```bash
extqc.py --xnat=nrgcentral --label=AB1234C --scan=3
```

If you have a NIfTI-1 file on disk, supply the `--input-nifti` argument

```bash
extqc.py --xnat=nrgcentral --label=AB1234C --scan=3 --input-nifti=/path/to/file.nii
```

> Note that if you're supplying DICOM or NIfTI-1 files directly, you're not 
> required to supply an `--xnat` argument. However, the auto report file will 
> not display a proper value for `MRScan.Project`. You can correct this by 
> supplying either `--project` or `--xnat`.

For more usage information, supply the `--help` argument

```bash
extqc.py --help
```

## Singularity
A `Singularity` bootstrap definition file is provided with this repository to 
help build an environment suitable for running `boldqc2`.

### Note about CentOS
I worked through this entire section using Singularity version 2.4.2 within a 
Vagrant bento/centos-6.7 box. I had to patch `base.py` from Singularity Python
module to inject a proxy into urllib2. Singularity appears not to support 
`$http_proxy` and `$https_proxy` environment variables.

### Resources
There are quite a few command line tools used by `boldqc2` that come from 
different software packages with different licenses. For this reason we only
describe how to bake these tools into the `boldqc2` image.

You must compress the necessary command line tools into a single file named 
`resources.tar` (should be about 160 MB) and copy that file into the cloned 
`boldqc2` repository directory before building the image. The internal 
structure of the `tar` file should be
 
```bash
resources
├── fsl
│   └── 4.1.7
│       └── bin
│           ├── fslhd
│           ├── fslorient
│           ├── fslswapdim
│           ├── fslswapdim_exe
│           ├── fslval
│           ├── mcflirt
│           ├── slicer
│           └── tmpnam
├── miniconda
│   └── 3.18.3
│       ├── LICENSE.txt
│       ├── bin
│       ├── conda-meta
│       ├── envs
│       ├── include
│       ├── lib
│       ├── pkgs
│       ├── share
│       └── ssl
└── mri_convert
    └── 2015_11_09
        ├── FreeSurferColorLUT.txt
        ├── bin
        │   ├── dcmdjpeg.fs
        │   ├── dcmdrle.fs
        │   └── mri_convert
        └── license.txt

```

If you have access to `ncfcode.rc.fas.harvard.edu` you can clone the tar file
using

```bash
git clone -b boldqc2-singularity-vm_local git@ncfcode.rc.fas.harvard.edu:nrg/resources.git
```

Again the `resources.tar` file must be copied or moved into the `boldqc2` repository 
directory before building the image.

### Building the image
The initialized singularity image should be about 3.5 GB

```bash
$ singularity image.create --size 3500 boldqc.img
$ sudo /usr/local/bin/singularity build boldqc.img Singularity
```

## Run the pipeline
```bash
$ singularity exec boldqc.img extqc.py --xnat cbscentral --label AB1234C --scan 1 --output-dir output --debug
DEBUG:pylib.xnat:issuing http request https://cbscentral.rc.fas.harvard.edu/data/experiments
[trimmed output]
```

