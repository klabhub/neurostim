%{
# Details of non-rigid motion correction performed on the imaging data
        -> master
        ---
        outlier_frames=null             : longblob      # mask with true for frames with outlier shifts (already corrected)
        block_height                    : int           # (pixels)
        block_width                     : int           # (pixels)
        block_depth                     : int           # (pixels)
        block_count_y                   : int           # number of blocks tiled in the y direction
        block_count_x                   : int           # number of blocks tiled in the x direction
        block_count_z                   : int           # number of blocks tiled in the z direction
%}
classdef MotionCorrectionNonRigid < dj.Part
        %Piece-wise rigid motion correction- tile the FOV into multiple 3D blocks/patches
end
