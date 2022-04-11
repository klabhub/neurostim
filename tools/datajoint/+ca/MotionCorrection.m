%{
#  Results of motion correction performed on the imaging data
    -> Curation
    ---
    -> scan.Channel.proj(motion_correct_channel='channel') # channel used for motion correction in this processing task
%}
classdef MotionCorrection < dj.Imported
end
