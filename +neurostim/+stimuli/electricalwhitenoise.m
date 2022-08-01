classdef electricalwhitenoise < neurostim.stimulus
    % Class for electrical white noise.
        
    properties
        bit = 1; % This is the mcc digital line bit, allowing control over which pin will carry this stimulus' on and off functions
        stimSets = {};
    end
    
    methods (Access = public)

        function s = electricalwhitenoise(c,name)
            
            s = s@neurostim.stimulus(c,name);
                        
            %% User-defined variables
            s.addProperty('random',1,'validate',@(x) {'logical'});
            s.addProperty('channels',[],'validate',@(x) {'numeric'});
            s.addProperty('numChannelFcn',@(x) poissrnd(x),'validate',@(x) {'char'});
            s.addProperty('lambda',1,'validate',@(x) {'numeric'});            
            s.addProperty('amplitudes',[],'validate',@(x) {'numeric'});
            s.addProperty('ampFcn',@(x,y) randi(x,y),'validate',@(x) {'char'});
            s.addProperty('minFrequency',[],'validate',@(x) {'numeric'});
            s.addProperty('maxFrequency',[],'validate',@(x) {'numeric'});
            s.addProperty('maxPulses',[],'validate',@(x) {'numeric'});

            s.addProperty('rngState',[]);       % Logged at the start of each trial.
            s.addProperty('stimVals',[]);       % If requested, just log all stimulation parameters.

            % We need our own RNG stream, to ensure its protected for stimulus reconstruction offline
            addRNGstream(s);
            
        end % constructor

        function beforeExperiment(s)
            s.onsetFunction = @(s,t) s.cic.mcc.digitalOut(8+s.bit,true);
            s.offsetFunction = @(s,t) s.cic.mcc.digitalOut(8+s.bit,false);
        end % beforeExperiment

        function beforeTrial(s)
            % Switch to the RNG stream
            r = RandStream.setGlobalStream(s.rng);
            % log the RNG state
            s.rngState = s.rng.State;
            
            if s.random
                s.initialise;
            else
                s.SabrinaPremadeFunction;
            end

            for ii = 1:numel(s.stimSets)
                if s.stimSets{ii}.enabled
                    % This function sets the current estim parameters to active in the Intan plugin
                    s.cic.intan.setActive(s.stimSets{ii});
                end
            end

            % restore global random stream
            RandStream.setGlobalStream(r);
        end % beforeTrial

         function afterTrial(s)
             s.offsetFunction(s,0);        % Forcibly turn the digital line to false
             s.stimVals = s.stimSets; % Necessary?
             s.stimSets = [];
         end % afterTrial

        function afterExperiment(s)
            % Make sure we log values from the final trial
            % Log the RNG state
            s.rngState = s.rng.State;
            % Log the stimVals
            s.stimVals = s.stimSets;
        end % afterExperiment

    end %methods (public)

    methods (Access = public)       

        function initialise(s)
            % How many channels will be active?
            nEnabled = s.numChannelFcn(s.lambda);
            if isempty(nEnabled)
                return;
            end
            % Which channels will be active?
            activeChns = randperm(numel(s.channels),nEnabled);            
            % What are their amplitudes?
            amp = s.ampFcn(numel(s.amplitudes),[1,nEnabled]);
            % How many pulses on each channel?
            pulses = randi(s.maxPulses,[1,nEnabled]);
            % What frequencies?
            freq = randi([s.minFrequency, s.maxFrequency],[1,nEnabled]);
            % Generate the stimulation parameter sets
            ns = cell(1,nEnabled);
            for ii = 1:nEnabled
                ns{ii} = s.newStimSet;
                ns{ii}.chn = activeChns(ii);
                ns{ii}.enabled = 1;
                ns{ii}.fpa = s.amplitudes(amp(ii));
                ns{ii}.spa = s.amplitudes(amp(ii));
                ns{ii}.pod = pulses(ii);
                ns{ii}.fre = freq(ii);
            end
            s.stimSets = ns;
        end
    end %methods (private)

    methods (Static, Access = public)

        function ns = newStimSet(varargin)
            % Input Parser
            p = inputParser();
            p.addParameter('enabled',0,@(x) validateattributes(x,{'numeric'},{'scalar','nonempty'}));
            p.addParameter('fpa',0,@(x) validateattributes(x,{'numeric'},{'scalar','nonempty'}));
            p.addParameter('spa',0,@(x) validateattributes(x,{'numeric'},{'scalar','nonempty'}));
            p.addParameter('fpd',200,@(x) validateattributes(x,{'numeric'},{'scalar','nonempty'}));
            p.addParameter('spd',200,@(x) validateattributes(x,{'numeric'},{'scalar','nonempty'}));
            p.addParameter('ipi',100,@(x) validateattributes(x,{'numeric'},{'scalar','nonempty'}));
            p.addParameter('pot',0,@(x) validateattributes(x,{'numeric'},{'scalar','nonempty'}));
            p.addParameter('nod',1,@(x) validateattributes(x,{'numeric'},{'scalar','nonempty'}));
            p.addParameter('nsp',0,@(x) validateattributes(x,{'numeric'},{'scalar','nonempty'}));
            p.addParameter('fre',0,@(x) validateattributes(x,{'numeric'},{'scalar','nonempty'}));
            p.addParameter('pod',0,@(x) validateattributes(x,{'numeric'},{'scalar','nonempty'}));
            p.addParameter('ptr',1e3,@(x) validateattributes(x,{'numeric'},{'scalar','nonempty'}));
            p.addParameter('chn','A-001',@(x) validateattributes(x,{'char'},{'nonempty'}));
            p.addParameter('prAS',200,@(x) validateattributes(x,{'numeric'},{'scalar','nonempty'}));
            p.addParameter('poAS',160000,@(x) validateattributes(x,{'numeric'},{'scalar','nonempty'}));
            p.addParameter('prCR',100000,@(x) validateattributes(x,{'numeric'},{'scalar','nonempty'}));
            p.addParameter('poCR',150000,@(x) validateattributes(x,{'numeric'},{'scalar','nonempty'}));
            p.addParameter('stSH',1,@(x) validateattributes(x,{'numeric'},{'scalar','nonempty'}));
            p.addParameter('enAS',1,@(x) validateattributes(x,{'numeric'},{'scalar','nonempty'}));
            p.addParameter('maAS',1,@(x) validateattributes(x,{'numeric'},{'scalar','nonempty'}));
            p.addParameter('enCR',1,@(x) validateattributes(x,{'numeric'},{'scalar','nonempty'}));
            p.addParameter('recDir','',@(x) validateattributes(x,{'char'},{'nonempty'}));
            p.addParameter('port','A',@(x) validateattributes(x,{'char'},{'nonempty'}));
            p.parse(varargin{:});
            args = p.Results;

            % Generate a new stimulation parameter set
            ns.enabled = args.enabled;
            ns.fpa = args.fpa;
            ns.spa = args.spa;
            ns.fpd = args.fpd;
            ns.spd = args.spd;
            ns.ipi = args.ipi;
            ns.pot = args.pot;
            ns.nod = args.nod;
            ns.nsp = args.nsp;
            ns.fre = args.fre;
            ns.pod = args.pod;
            ns.ptr = args.ptr;
            ns.prAS = args.prAS;
            ns.poAS = args.poAS;
            ns.prCR = args.prCR;
            ns.poCR = args.poCR;
            ns.stSH = args.stSH;
            ns.enAS = args.enAS;
            ns.maAS = args.maAS;
            ns.enCR = args.enCR;
            ns.port = args.port;
        end % newStimList

    end % methods (static, private)
end %classdef