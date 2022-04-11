%{
# FOV-tiled blocks used for non-rigid motion correction
        -> master.NonRigidMotionCorrection
        block_id        : int
        ---
        block_y         : longblob  # (y_start, y_end) in pixel of this block
        block_x         : longblob  # (x_start, x_end) in pixel of this block
        block_z         : longblob  # (z_start, z_end) in pixel of this block
        y_shifts        : longblob  # (pixels) y motion correction shifts for every frame
        x_shifts        : longblob  # (pixels) x motion correction shifts for every frame
        z_shifts=null   : longblob  # (pixels) x motion correction shifts for every frame
        y_std           : float     # (pixels) standard deviation of y shifts across all frames
        x_std           : float     # (pixels) standard deviation of x shifts across all frames
        z_std=null      : float     # (pixels) standard deviation of z shifts across all frames
%}
classdef Block < dj.Part
end