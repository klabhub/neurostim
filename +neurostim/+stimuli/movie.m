classdef movie < neurostim.stimulus
    % Stimulus class to present movies as textures (without using
    % GStreamer, which does not play nice with the Matlab JVM).
    %
    % This class uses the VideoReader to read the movie files and convert
    % to OpenGL textures in the interrial interval. For a 1 MB movie (20
    % seconds at 30 fps), this takes about 4 seconds -= so a long ITI
    % should be expected. With some additional bookkeeping this could be
    % pushed to the beforeExperiment phase (to load multiple movies to
    % texture memory at the start of the experiment)
    %
    % 
    % Settable properties:
    %   id      - id(s) of the texture(s) to show on
    %             the next frame
    %   width   - width on screen (screen units)
    %   hight   - height on screen (screen units)
    %   X
    %   Y
    %   orientation - in degrees.
    %   filename  - full path to the movie file. This must be one of the
    %   formats that VideoReader can interpret.
    %   path - If filename is not a full path, specify a path separately
    %   here.
    % 
    %   framerate - the framerate at which to play the Movie (defaults to the rate in the file)
    %   filterMode - Texture filterModes - 1 = bilinear, the default.  For higher quality, increase the number (up to 5). See Screen('DrawTexture?') for details.  
    %   loop - Loop the movie within a trial.
    %
    % Read only properties   
    %   nrFrames = nmber of frames in the movie
    %   xPixels , yPixels native number of pixels in the movie file.
    % 
    %  BK - May 2019
    
    properties (Access = private)
        % Each frame will be associated with a texture
        tex = [];       % Vector fo texture pointers 
        rect =[];       % Rect to apply the texture
        fracFrameCntr;      % Current fractional frame cntr.
        currentlyLoadedFile = '';  % Full path to currently loaded file.
    end
    
    
    methods (Access = public)
        function o = movie(c,name)
            o = o@neurostim.stimulus(c,name);
            o.addProperty('width',[],'validate',@isnumeric);
            o.addProperty('height',[],'validate',@isnumeric);
            o.addProperty('xPixels',[],'validate',@isnumeric);
            o.addProperty('yPixels',[],'validate',@isnumeric);
            o.addProperty('nrFrames',[],'validate',@isnumeric);
            o.addProperty('filename','','validate',@ischar);
            o.addProperty('path','','validate',@(x) (ischar(x) && exist(x,'dir')));
            o.addProperty('filterMode',1,'validate',@(x) ismember(x,[0:5]));
            o.addProperty('framerate',[],'validate',@isnumeric);
            o.addProperty('orientation',0,'validate',@isnumeric);
            o.addProperty('loop',false,'validate',@islogical);
        end
        
        
        function afterExperiment(o)
            % clean up the textures
            Screen('Close',o.tex);
            o.tex = [];
        end
        
        function beforeTrial(o)
            % Check what the current filename is, load it if necessary
            if isempty(o.path)
                file = o.filename;
            else
                file = fullfile(o.path,o.filename);
            end
            if strcmpi(o.currentlyLoadedFile,file)
                % No need to reload
            else
                % Cleanup textures from the previous movie
                Screen('Close',o.tex);
                if ~exist(file,'file')
                    error(['Movie file : ' file ' could not be found']);
                end
                try
                    % tic
                    % Use the VideoReader object to read each of the frames
                    % and put it in texture memory.
                    obj = VideoReader(file);
                    o.xPixels = obj.Width;
                    o.yPixels = obj.Height;                    
                    if isempty(o.framerate)
                        o.framerate = obj.FrameRate;
                    end
                    % create the textures
                    i=0;
                    while hasFrame(obj)
                        i=i+1;
                        o.tex(i) = Screen('MakeTexture',o.window,readFrame(obj));
                    end
                    o.nrFrames =i;
                    % toc
                catch me
                    me.message
                    error(['Could not load the movie : ' file]);
                end
                o.currentlyLoadedFile =file;
            end
            
            % Determine the currently requested size of the movie
            if isempty(o.width)
                % Do not scale
                o.width = o.cic.screen.width*o.xPixels/o.cic.screen.xpixels;
            end
            if isempty(o.height)
                % Do not scale
                o.height = o.cic.screen.height*o.yPixels/o.cic.screen.ypixels;
            end
            o.rect = 0.5*[-o.width -o.height o.width o.height];
            o.fracFrameCntr=  1;% Reset the fractional frame cntr
            
        end
        
        function beforeFrame(o)
            if isempty(o.tex); return; end % Nothing to do
            % Increase the fractional frame cntr by some amount determined
            % by the desired framerate and the actual (targeted) framerate
            % of the application.
            o.fracFrameCntr = o.fracFrameCntr+o.framerate/o.cic.screen.frameRate;
            if o.loop
                thisFrame = mod(floor(o.fracFrameCntr)-1,o.nrFrames)+1;
            else
                thisFrame = floor(o.fracFrameCntr);
            end
            
            if thisFrame <= o.nrFrames
                % These are not currently used/varied but could be added if neeed.
                globalAlpha=1;modulateColor=[];textureShader=[];specialFlags=[];auxParameters=[];
                Screen('DrawTextures',o.window,o.tex(thisFrame),[],o.rect,o.orientation,o.filterMode,globalAlpha,modulateColor,textureShader,specialFlags,auxParameters);
            end
        end
    end % public methods
    
    
end
