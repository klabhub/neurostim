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
    % can be found at https://github.com/duijnhouwer/udpcam
    properties (Access=public)
        RC@udpcam_remote_control;
    end
    methods (Access=public)
        function o=webcam(c,name)
            if nargin==1
                name=mfilename;
            end
            o=o@neurostim.plugin(c,name);
            o.addProperty('base_video_name','webcamvid.mj2');
            o.RC=udpcam_remote_control;
        end
        %function beforeExperiment(o)
         %   [ok,infostr]=o.RC.test_connection;
         %   if ~ok
         %       warning(infostr);
         %   end
         %end
         function beforeTrial(o)
             % append the filename with the condition and trial number
             [fld,nm,xt]=fileparts(o.base_video_name);
             nm=sprintf('%s_c%.3d_tr%.5d',nm, o.cic.condition,o.cic.trial);
             fname=fullfile(fld,[nm xt]);
             % set the file name
             o.RC.send(sprintf('out>vid>filename=''%s''',fname));
             % start recording
             o.RC.send('rec');
         end
         function afterTrial(o)
             o.RC.send('stop');
         end
         function afterExperiment(o)
             delete(o.RC)
         end
    end
end
