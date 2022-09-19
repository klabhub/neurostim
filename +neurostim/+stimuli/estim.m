classdef estim < neurostim.stimulus
    % Base class for electrical stimuli in PTB.    
    % Adjustable variables:
    %   dph - duration of each phase of the stimulus waveform (eg. 200 us)
    %   ipi - inter-phase interval (eg. 100 us)   
    %   nsp - the number of stimulation pulses
    %   fre - the frequency of stimulation pulses
    %   chn - the channel stimulation is delivered on
    %   on - time the stimulus should come 'on' (ms) from start of trial
    %   duration - time the stimulus should turn 'off' (ms) from start of trial
    %   enabled - turn stimulation on or off
    %   fpa - first phase amplitude of stimulus waveform (eg. 10 uA)
    %   spa - second phase amplitude of stimulus waveform (eg. 10 uA)
    %   fpd - duration of first phase of the stimulus waveform (eg. 200 us)
    %   spd - duration of second phase of the stimulus waveform (eg. 200 us)    
    %   pot - controls single-pulse or multi-pulse stimulation trains
    %   nod - controls number of stimulation pulses in train, or duration
    %   pod - duration of stimulation pulses (us). Max 99 pulses
    %   ptr - post-stimulation pulse train refractory period
    %   prAS - pre-stimulation amp settle ON time
    %   poAS - post-stimulation amp settle OFF time
    %   prCR - post-stimulation charge recovery ON time
    %   poCR - post-stimulation charge recovery OFF time
    %   stSH - stimulation shape (eg. biphasic, triphasic, cathodic-first. See Intan for codes)
    %   enAS - controls amp settle enabled
    %   maAS - maintain or end amp settle throughout stimulation pulse train
    %   enCR - controls charge recovery enabled
    %   recDir - specify the recording directory for Intan
    %   settingsFile - specify an Intan general settings file
    %   port - controls which port Intan uses for stimulation ('A','B','C','D')
    
    properties
        bit = 1;            % This is the mcc digital line bit, allowing control over which pin will carry this stimulus' on and off functions
        mccCntr = 1;        % Decides whether this estim class will take control of the digital line
    end
    
    methods (Access = public)
        function s = estim(c,name)
            s = s@neurostim.stimulus(c,name);            
            %% user-settable properties
            s.addProperty('enabled',0,'validate',@isnumeric);
            s.addProperty('fpa',0,'validate',@isnumeric);
            s.addProperty('spa',0,'validate',@isnumeric);
            s.addProperty('fpd',0,'validate',@isnumeric);
            s.addProperty('spd',0,'validate',@isnumeric);
            s.addProperty('ipi',0,'validate',@isnumeric);
            s.addProperty('pot',0,'validate',@isnumeric);
            s.addProperty('nod',1,'validate',@isnumeric);
            s.addProperty('nsp',0,'validate',@isnumeric);
            s.addProperty('fre',80,'validate',@isnumeric);
            s.addProperty('pod',0,'validate',@isnumeric);
            s.addProperty('ptr',1e3,'validate',@isnumeric);
            s.addProperty('chn','A-001','validate',@ischar);
            s.addProperty('prAS',200,'validate',@isnumeric);
            s.addProperty('poAS',160000,'validate',@isnumeric);
            s.addProperty('prCR',100000,'validate',@isnumeric);
            s.addProperty('poCR',150000,'validate',@isnumeric);
            s.addProperty('stSH',1,'validate',@isnumeric);
            s.addProperty('enAS',1,'validate',@isnumeric);
            s.addProperty('maAS',1,'validate',@isnumeric);
            s.addProperty('enCR',1,'validate',@isnumeric);
            s.addProperty('recDir','','validate',@ischar);
            s.addProperty('port','','validate',@ischar);
        end
        function beforeExperiment(s)
            if s.mccCntr
                s.onsetFunction = @(s,t) s.cic.mcc.digitalOut(8+s.bit,true);
                s.offsetFunction = @(s,t) s.cic.mcc.digitalOut(8+s.bit,false);
            end
        end
        function beforeTrial(s)
            if s.enabled
                % This function sets the current estim parameters to active in the Intan plugin
                s.cic.intan.setActive(s);
            end
        end
    end    
end %classdef