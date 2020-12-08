import os
import io
import re
import sys
import json
import time
import numpy as np
import zipfile as zf
import datetime as dt
import pylib.fun as fun
import lxml.etree as et

NSMAP = {
    None: 'http://www.neuroinfo.org/neuroinfo',
    'xsi': 'http://www.w3.org/2001/XMLSchema-instance',
    'xnat': 'http://nrg.wustl.edu/xnat',
    'neuroinfo': 'http://www.neuroinfo.org/neuroinfo'
}
    
FILES = [
    {
        'content': 'Mean NIFTI',
        'label': 'Mean NIFTI',
        'file': '{OUTDIR}/extended-qc/{ASSESSOR_ID}_mean.nii.gz',
        'type': 'image/nifti1',
        'file_list': False
     },
     {
        'content': 'Mean Image',
        'label': 'Mean Image',
        'file': '{OUTDIR}/extended-qc/{ASSESSOR_ID}_mean_thumbnail.png',
        'type': 'image/png',
        'file_list': True
     },
     {
        'content': 'Mean Slice Data',
        'label': 'Mean Slice Data',
        'file': '{OUTDIR}/extended-qc/{ASSESSOR_ID}_mean_slice.txt',
        'type': 'text/plain',
        'file_list': False
     },
     {
        'content': 'Mean Data',
        'label': 'Mean Data',
        'file': '{OUTDIR}/extended-qc/{ASSESSOR_ID}_mean_slice.png',
        'type': 'image/png',
        'file_list': True
     },
     {
        'content': 'Mask NIFTI',
        'label': 'Mask NIFTI',
        'file': '{OUTDIR}/extended-qc/{ASSESSOR_ID}_mask.nii.gz',
        'type': 'image/nifti1',
        'file_list': False
     },
     {
        'content': 'Mask Image',
        'label': 'Mask Image',
        'file': '{OUTDIR}/extended-qc/{ASSESSOR_ID}_mask_thumbnail.png',
        'type': 'image/png',
        'file_list': True
     },
     {
        'content': 'SNR NIFTI',
        'label': 'SNR NIFTI',
        'file': '{OUTDIR}/extended-qc/{ASSESSOR_ID}_snr.nii.gz',
        'type': 'image/nifti1',
        'file_list': False
     },
     {
        'content': 'SNR Image',
        'label': 'SNR Image',
        'file': '{OUTDIR}/extended-qc/{ASSESSOR_ID}_snr_thumbnail.png',
        'type': 'image/png',
        'file_list': True
     },
     {
        'content': 'SD NIFTI',
        'label': 'SD NIFTI',
        'file': '{OUTDIR}/extended-qc/{ASSESSOR_ID}_stdev.nii.gz',
        'type': 'image/nifti1',
        'file_list': False
     },
     {
        'content': 'SD Image',
        'label': 'SD Image',
        'file': '{OUTDIR}/extended-qc/{ASSESSOR_ID}_stdev_thumbnail.png',
        'type': 'image/png',
        'file_list': True
     },
     {
        'content': 'Motion Data',
        'label': 'Motion Data',
        'file': '{OUTDIR}/extended-qc/{ASSESSOR_ID}_motion.png',
        'type': 'image/png',
        'file_list': True
     },
     {
        'content': 'Slope Image',
        'label': 'Slope Image',
        'file': '{OUTDIR}/extended-qc/{ASSESSOR_ID}_slope_thumbnail.png',
        'type': 'image/png',
        'file_list': True
     },
     {
        'content': 'Slope NIFTI',
        'label': 'Slope NIFTI',
        'file': '{OUTDIR}/extended-qc/{ASSESSOR_ID}_slope.nii.gz',
        'type': 'image/nifti1',
        'file_list': False
     },
      {
        'content': 'QC Report',
        'label': 'QC Report',
        'file': '{OUTDIR}/extended-qc/{ASSESSOR_ID}_auto_report.txt',
        'type': 'text/plain',
        'file_list': True
     },
    {
        'content': 'Slice Report',
        'label': 'Slice Report',
        'file': '{OUTDIR}/extended-qc/{ASSESSOR_ID}_slice_report.txt',
        'type': 'text/plain',
        'file_list': True
     }
]

AUTO_REPORT_TOKENS = [
    'InFile',            'Size',
    'N_Vols',            'Skip',
    'qc_N_Tps',          'qc_thresh',
    'qc_nVox',           'qc_Mean',
    'qc_Stdev',          'qc_sSNR',
    'qc_vSNR',           'qc_slope',
    'mot_N_Tps',         'mot_rel_x_mean',
    'mot_rel_x_sd',      'mot_rel_x_max',
    'mot_rel_x_1mm',     'mot_rel_x_5mm', 
    'mot_rel_y_mean',    'mot_rel_y_sd', 
    'mot_rel_y_max',     'mot_rel_y_1mm',
    'mot_rel_y_5mm',     'mot_rel_z_mean',
    'mot_rel_z_sd',      'mot_rel_z_max',
    'mot_rel_z_1mm',     'mot_rel_z_5mm',
    'mot_rel_xyz_mean',  'mot_rel_xyz_sd',
    'mot_rel_xyz_max',   'mot_rel_xyz_1mm',
    'mot_rel_xyz_5mm',   'rot_rel_x_mean',
    'rot_rel_x_sd',      'rot_rel_x_max',
    'rot_rel_y_mean',    'rot_rel_y_sd',
    'rot_rel_y_max',     'rot_rel_z_mean',
    'rot_rel_z_sd',      'rot_rel_z_max',
    'mot_abs_x_mean',
    'mot_abs_x_sd',      'mot_abs_x_max',
    'mot_abs_y_mean',    'mot_abs_y_sd',
    'mot_abs_y_max',     'mot_abs_z_mean',
    'mot_abs_z_sd',      'mot_abs_z_max',
    'mot_abs_xyz_mean',  'mot_abs_xyz_sd',
    'mot_abs_xyz_max',   'rot_abs_x_mean',
    'rot_abs_x_sd',      'rot_abs_x_max',
    'rot_abs_y_mean',    'rot_abs_y_sd', 
    'rot_abs_y_max',     'rot_abs_z_mean',
    'rot_abs_z_sd',      'rot_abs_z_max'
]

def xar(d, project, label, aid, scan, state, outfile=None):
    '''
    Generate XNAT archive for ExtendedBOLDQC pipeline
    '''
    xarchive = os.path.join(d, 'xar-%s.zip' % fun.iso8601())
    if not outfile:
        outfile = io.BytesIO()
    xarfile = zf.ZipFile(outfile, 'w')
    # add ASSESSMENT_FOLDER files
    for f in FILES:
        fullfile = f['file'].format(OUTDIR=d, ASSESSOR_ID=label)
        fname = os.path.basename(fullfile)
        if not os.path.exists(fullfile):
            raise MissingFileError('file missing %s' % fullfile)
        with open(fullfile, 'rb') as fo:
            xarfile.writestr('ASSESSMENT_FOLDER/%s' % fname, fo.read())
    # add ASSESSMENT.XML
    ass_xml = assessment_xml(d, aid, label, project, scan, state)
    ass = et.tostring(ass_xml, pretty_print=True)
    xarfile.writestr('ASSESSMENT.XML', ass)
    if outfile:
        xarfile.close()
    return xarfile

class MissingFileError(Exception):
    pass

def assessment_xml(d, aid, label, project, scan_id, state):
    # shorthand for commonly used namespaces
    xnatns = '{%s}' % NSMAP['xnat']
    xsins = '{%s}' % NSMAP['xsi']

    # root element
    root = et.Element('ExtendedBOLDQC', ID=label, 
                      label=label, project=project, 
                      nsmap=NSMAP)

    # xnat:date and xnat:time elements
    ts = time.time()
    date_now = dt.datetime.fromtimestamp(ts).strftime('%Y-%m-%d')
    time_now = dt.datetime.fromtimestamp(ts).strftime('%H:%M:%S')
    et.SubElement(root, xnatns + 'date').text = date_now
    et.SubElement(root, xnatns + 'time').text = time_now

    # xnat:out and xnat:file elements
    xnat_out = et.SubElement(root, xnatns + 'out')
    for f in FILES:
        xnat_file = et.SubElement(xnat_out, xnatns + 'file')
        xnat_file.set('content', f['content'])
        xnat_file.set('label', f['label'])
        fullfile = f['file'].format(OUTDIR='none', ASSESSOR_ID=label)
        fname = os.path.basename(fullfile)
        xnat_file.set('URI', fname)
        xnat_file.set('format', f['type'])
        xnat_file.set(xsins + 'type', 'xnat:resource')
        if f['file_list']:
            xnat_tags = et.SubElement(xnat_file, xnatns + 'tags')
            et.SubElement(xnat_tags, xnatns + 'tag').text = 'file_list'

    # imageSession_ID element
    et.SubElement(root, xnatns + 'imageSession_ID').text = aid

    # pipeline elements
    xnat_pipeline = et.SubElement(root, xnatns + 'pipeline')
    et.SubElement(xnat_pipeline, xnatns + 'status').text = 'COMPLETE'
    et.SubElement(xnat_pipeline, xnatns + 'message').text = 'The ExtendedQC pipeline ran successfully.'

    # scan element
    scan = et.SubElement(root, 'scan')

    # add front-end prov element
    prov = et.SubElement(scan, 'prov')
    et.SubElement(prov, 'start_date').text = state.start_date
    et.SubElement(prov, 'start_time').text = state.start_time
    et.SubElement(prov, 'username').text = state.username
    et.SubElement(prov, 'initial_cwd').text = state.initial_cwd
    et.SubElement(prov, 'command_line').text = ' '.join(state.command)
    et.SubElement(prov, 'runtime_secs').text = str(state.runtime )
    et.SubElement(prov, 'os').text = state.os
    et.SubElement(prov, 'hostname').text = state.hostname
    prov_exe = et.SubElement(prov, 'executable')
    exe = os.path.abspath(state.exe)
    et.SubElement(prov_exe, 'name').text = os.path.basename(state.exe)
    et.SubElement(prov_exe, 'path').text = os.path.dirname(state.exe)
    et.SubElement(prov_exe, 'sha256sum').text = state.checksum
    et.SubElement(prov_exe, 'mtime').text = state.mtime

    # add sub-process provenance elements
    for p in state.provenance:
        p = _provtoxml(p)
        prov.append(p)

    # add scan_id and session_id elements
    et.SubElement(scan, 'scan_id').text = str(scan_id)
    et.SubElement(scan, 'session_id').text = aid

    # get qc_Min and qc_Max values from *_slice_report.txt
    f = os.path.join(os.path.join(d, 'extended-qc'), '{0}_slice_report.txt'.format(label))
    with open(f, 'rb') as fo:
        qc_min,qc_max = _parse_slice_report(fo)

    # add metrics from *_auto_report.txt and qc_Min, qc_Max
    f = os.path.join(os.path.join(d, 'extended-qc'), '{0}_auto_report.txt'.format(label))
    with open(f, 'rb') as fo:
        report = _parse_auto_report(fo.read(), AUTO_REPORT_TOKENS)
    for t in AUTO_REPORT_TOKENS:
        # sneak in qc_Max and qc_Min after qc_Mean
        if t == 'qc_Mean':
            et.SubElement(scan, t).text = report[t]    
            et.SubElement(scan, 'qc_Max').text = str(qc_max)
            et.SubElement(scan, 'qc_Min').text = str(qc_min)
            continue
        et.SubElement(scan, t).text = report[t]    

    # return xml object
    return root

def _parse_slice_report(f):
    ''' get qc_min an qc_max metrics from slice_report.txt '''
    start_line = re.compile('^slice\s+voxels\s+mean\s+stdev\s+snr\s+min\s+max\s+#out$')
    end_line = re.compile('^VOXEL.*$')
    data = []
    for line in f:
        line = line.strip()
        if start_line.match(line):
            break
    for line in f:
        line = line.strip()
        if end_line.match(line):
            break
        if line:
            data.append([float(x) for x in line.split()])
    data = np.array(data)
    return np.min(data[:,5]), np.max(data[:,6])
 
def _parse_auto_report(s, tokens):
    ''' parse auto_report.txt metrics into a dictionary '''
    data = {}
    expr = r'^{0}\s+(.*)$'
    for t in tokens:
        search_t = t
        if t == 'InFile':
            search_t = 'InputFile'
        if t == 'Size':
            search_t = 'InputFileSize'
        result = re.search(expr.format(search_t), s, flags=re.MULTILINE)
        if not result:
            raise ParseError('did not find token "%s" in auto report file' % search_t)
        data[t] = result.group(1)
    return data

class ParseError(Exception):
    pass

def _provtoxml(p):
    ''' convert a prov dictionary to XML '''
    f = os.path.join(p.dirname, p.basename)
    prov = et.Element('prov')
    et.SubElement(prov, 'start_date').text = p.start_date
    et.SubElement(prov, 'start_time').text = p.start_time
    et.SubElement(prov, 'username').text = p.username
    et.SubElement(prov, 'initial_cwd').text = p.cwd
    et.SubElement(prov, 'command_line').text = ' '.join(p.command)
    et.SubElement(prov, 'runtime_secs').text = str(p.elapsed)
    et.SubElement(prov, 'os').text = p.os
    et.SubElement(prov, 'hostname').text = p.hostname
    exe = et.SubElement(prov, 'executable')
    et.SubElement(exe, 'name').text = p.basename
    et.SubElement(exe, 'path').text = p.dirname
    et.SubElement(exe, 'sha256sum').text = p.checksum
    et.SubElement(exe, 'mtime').text = dt.datetime.fromtimestamp(os.path.getmtime(f)).isoformat()
    return prov

