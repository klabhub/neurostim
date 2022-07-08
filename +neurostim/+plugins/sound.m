classdef sound < neurostim.plugin
    % Generic sound plugin for PTB. Add if using sound.
    properties (Access=public)
       
    end
    properties (SetAccess=protected,GetAccess=public)
        paHandle
    end
    
    properties (Dependent)
        status; 
        sampleRate;
        latency;
    end
    
    methods
        function v = get.status(o)
            v = PsychPortAudio('GetStatus', o.paHandle);
        end
        
        function v= get.sampleRate(o)
            st = o.status;
            v = st.SampleRate;
        end
        
        function v= get.latency(o)
            st = o.status;
            v = st.PredictedLatency/1000; % ms
        end
                
    end
    
    
    methods (Access=public)
        function o=sound(c,latencyClass)
            if nargin <2
                latencyClass = c.hardware.sound.latencyClass; % Latency is a priority
%   From PsychPortAudio('Open?'): Allows to select how aggressive PsychPortAudio should be about
% minimizing sound latency and getting good deterministic timing, i.e. how to
% trade off latency vs. system load and playing nicely with other sound
% applications on the system. Level 0 means: Don't care about latency, this mode
% works always and with all settings, plays nicely with other sound applications.
% Level 1 (the default) means: Try to get the lowest latency that is possible
% under the constraint of reliable playback, freedom of choice for all parameters
% and interoperability with other applications. Level 2 means: Take full control
% over the audio device, even if this causes other sound applications to fail or
% shutdown. Level 3 means: As level 2, but request the most aggressive settings
% for the given device. Level 4: Same as 3, but fail if device can't meet the
% strictest requirements.
%                 
            end
            o=o@neurostim.plugin(c,'sound');
            o.addProperty('latencyClass',latencyClass);
            
            % Sound initialization
            clear PsychPortAudio;   %Class seems to be not properly cleared sometimes, when Neurostim doesn't close gracefully.
            InitializePsychSound(latencyClass);
            
            % Opening here instead of beforeExperiment so that the actual
            % sampleRate is available for resampling in classes that use
            % this plugin (e.g. soundFeedback)
            PsychPortAudio('Close'); % Start fresh (without this the next line can fail as Open can only be called once).
            o.paHandle = PsychPortAudio('Open',c.hardware.sound.device, [], latencyClass);
                            
            
             %Play a dummy sound (first sound wasn't playing)
             try
                bufferHandle = PsychPortAudio('CreateBuffer',o.paHandle,[0; 0]);
             catch
                error('Could not create audio output. Is your audio output device on?');
             end
            PsychPortAudio('FillBuffer', o.paHandle,bufferHandle);
            PsychPortAudio('Start',o.paHandle);
            
        end
        
        
      
        function afterExperiment(o)
            PsychPortAudio('DeleteBuffer');
            PsychPortAudio('Close', o.paHandle);
        end
        
        function bufferHandle = createBuffer(o,waveform)
            
            %If a vector (mono), force to be a row
            if isvector(waveform)
                waveform = waveform(:)';
                waveform = [waveform; waveform];
            end
            
            %If neither mono, nor stereo
            if ~any(size(waveform)==2)
                error('Waveform data must be either a vector (mono) or two-column matrix (stereo)');
            end
            
            %Ensure 2 x N matrix
            if size(waveform,2)==2
                waveform = waveform';
            end
            
               bufferHandle = PsychPortAudio('CreateBuffer',o.paHandle,waveform);
        end
        
        function beep(o,frequency,duration)       
            % Create and immediately play a beep of given sound and
            % duration.  This is used for feedback by the Eyelink dispatch
            % callback. Note that this is not meant for low-latency timing.            
            w = MakeBeep(frequency,duration,o.sampleRate); % Use PTB function
            hBuffer = o.createBuffer(w);
            o.play(hBuffer);
            o.deleteBuffer(hBuffer);
        end
            
        
        function play(o,bufferHandle,varargin)
            % Start playing a specific buffer handle. 
            % Takes the input arguments of PsychPortAudio('Start') to time
            % stimulus onset.
            % 
            p=inputParser;
            p.addParameter('repetitions',1,@isnumeric);
            p.addParameter('when',0,@isnumeric);
            p.addParameter('waitForStart',0,@isnumeric);
            p.addParameter('stopTime',inf,@isnumeric);
            p.addParameter('resume',0,@isnumeric);
            p.parse(varargin{:});
            % PsychPortAudio('Start', pahandle [, repetitions=1] [, when=0] [, waitForStart=0] [, stopTime=inf] [, resume=0]);
            
            PsychPortAudio('FillBuffer', o.paHandle,bufferHandle);
            
            % Play sound, passs options  (default is play immediately)
            PsychPortAudio('Start',o.paHandle,p.Results.repetitions,p.Results.when,p.Results.waitForStart,p.Results.stopTime,p.Results.resume);
        end
        
        function stop(o,varargin)
            p=inputParser;
            p.addParameter('repetitions',[],@isnumeric);
            p.addParameter('waitForEndOfPlayback',0,@isnumeric);
            p.addParameter('stopTime',[],@isnumeric);
            p.addParameter('blockUntilStopped',0,@isnumeric);
            p.parse(varargin{:});
            PsychPortAudio('Stop',o.paHandle,p.Results.waitForEndOfPlayback,p.Results.blockUntilStopped,p.Results.repetitions,p.Results.stopTime); 
        end
        
        function reschedule(o,varargin)
            p=inputParser;
            p.addParameter('repetitions',[],@isnumeric);
            p.addParameter('waitForStart',0,@isnumeric);
            p.addParameter('stopTime',[],@isnumeric);
            p.addParameter('when',0,@isnumeric);
            p.parse(varargin{:});
            PsychPortAudio('RescheduleStart',o.paHandle,p.Results.when, p.Results.waitForStart,p.Results.repetitions,p.Results.stopTime); 
        end
        
        function refillBuffer(o,targetBufferHandle,sourceBufferDataOrHandle,startIndex)
            if nargin <4
                startIndex =0;
            end
            PsychPortAudio('RefillBuffer',o.paHandle,targetBufferHandle,sourceBufferDataOrHandle,startIndex);   
        end
        
        
        function deleteBuffer(o,bufferHandle)
            % Delete a specified vector of buffers
            for i=1:numel(bufferHandle)
                PsychPortAudio('DeleteBuffer',bufferHandle(i));
            end
        end
        
        function delete(o) %#ok<INUSD>
            clear PsychPortAudio;
        end
    end
end