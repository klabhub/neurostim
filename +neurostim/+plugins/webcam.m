classdef webcam < neurostim.plugin
    
    % Plugin to control udpcam to record video with a webcam during an
    % experiment and save the results to file. udpcam should be run in a
    % separate matlab session (start one using !matlab&) or packaged as a
    % windows executable. an earlier effort grabbed frames from the webcam
    % within neurostim, in afterframe. but that doesn't work because
    % grabbing a frame from the webcam locks up execution until the webcam
    % has a new frame ready. Because webcams typically run at 15-30Hz, this
    % caused massive framedrops. updcam and it's companian class
    % updcam_remote_control (around which this plugin is merely a wrapper)
    can be found at https://github.com/duijnhouwer/udpcam
    properties (Access=public)
        RC@udpcam_remote_control;
    end
    methods (Access=public)
        function o=webcam(c,name)
            if nargin==1
                name=mfilename;
            end
            o=o@neurostim.plugin(c,name);
            o.RC=udpcam_remote_control;
        end
        function afterExperiment(o)
            delete(o.RC)
        end
    end
end
