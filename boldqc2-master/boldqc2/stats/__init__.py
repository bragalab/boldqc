import logging
import numpy as np
import collections as c

logger = logging.getLogger(__name__)

VoxelStats = c.namedtuple('VoxelStats', ["mean_dat", "std_dat", "snr_dat", "snr"])
SliceStats = c.namedtuple('SliceStats', ["summary", "mean", "std", "snr"])
SliceRow = c.namedtuple("SliceRow", ["num", "mean", "std", "snr"])

def voxel_based_stats(dat, mask):
    '''
    Compute voxel-based statistics
    
    :param dat: Data matrix
    :type dat: numpy.array
    :param mask: Binary mask
    :type mask: numpy.array
    :returns: Tuple of ['mean_dat', 'std_dat', 'snr_dat', 'snr']
    :rtype: collections.namedtuple
    '''
    # create a raw mean image, collapsed along the time axis
    mean_dat = dat.mean(axis=3)
    # create a standard deviation (std) image, collapsed along the time axis
    std_dat = dat.std(axis=3, ddof=1)
    # since we need to divide by the std image, zeros will be problematic
    std_dat[std_dat == 0] = 1.0
    # compute the raw snr image
    snr_dat = mean_dat / std_dat
    # compute the mean of the voxel-based SNRs within the mask
    vsnr = np.ma.array(snr_dat, mask=mask).mean()
    
    return VoxelStats(mean_dat, std_dat, snr_dat, vsnr)
    
def slice_based_stats(dat, mask):
    '''
    Compute slice-based statistics
    :param dat: Data matrix
    :type dat: numpy.array
    :param mask: Binary mask
    :type mask: numpy.array
    :returns: Tuple of ['summary', 'mean', 'std', 'snr']
    :rtype: collections.namedtuple
    '''
    # get the length of each dimension into named variables
    _,_,z,t = dat.shape
    # create slice means for every volume independently
    slice_means = c.defaultdict(list)
    for i in range(t):
        # get the i'th volume
        volume = np.ma.array(dat[:,:,:,i], mask=mask)
        for j in range(z):
            # get the j'th slice from the i'th volume
            slice_ij = volume[:,:,j]
            # compute and retain the slice mean
            slice_means[j].append(slice_ij.mean())
    # compute the raw and weighted means, stds, and snrs
    slice_wmean_sum = 0
    slice_wstd_sum = 0
    slice_wsnr_sum = 0
    total_masked_voxels = 0
    slice_summary = []
    for i,volume_means in iter(slice_means.items()):
        # cast volume means to a numpy array to make life easier
        volume_means = np.array(volume_means)
        # compute the raw slice mean across time
        mean = volume_means.mean()
        # compute the raw slice std across time
        std = volume_means.std(ddof=1)
        # compute the raw slice snr across time
        snr = mean / std
        # store raw statistics within the slice summary
        slice_summary.append(SliceRow(i + 1, mean, std, snr))
        # count the number of un-masked voxels for the i'th slice
        num_masked_voxels = (mask[:,:,i] == False).sum()
        # keep a running sum of the number of un-masked voxels
        total_masked_voxels += num_masked_voxels
        # keep running sums of the weighted mean, std, and snr
        slice_wmean_sum += volume_means.mean() * num_masked_voxels
        slice_wstd_sum += volume_means.std(ddof=1) * num_masked_voxels
        slice_wsnr_sum += (mean / std) * num_masked_voxels
    # compute the weighted slice-based mean, standard deviation, and snr
    wm = slice_wmean_sum / total_masked_voxels
    ws = slice_wstd_sum / total_masked_voxels
    wsnr = slice_wsnr_sum / total_masked_voxels
    
    return SliceStats(slice_summary, wm, ws, wsnr)

