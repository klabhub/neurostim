classdef liquid < neurostim.plugins.feedback
    % Feedback plugin to deliver liquid reward through some external hardware device.
    % 'device'  -the name of a plugin to use to deliver reward ('mcc',
    %           'ripple')
    %  'deviceFun' -  A member function of the device plugin that will be
    %               called to open and close the liquid reward Can be char
    %               or a function handle.
    %               This function will be called as follows when reward is
    %               supposed to be delivered.
    %                   fun(device,deviceChannel,true,duration)
    %               This function should open and then close the spout some
    %               duration ms later. (See plugins.ripple).
    %               At the start of the experiment and at the end, the same
    %               funciton is called to make sure everything is in the
    %               closed state:
    %                   fun(device,deviceChannel,false);
    % 'deviceChannel' - The channel to use in the hardware device.
    % 'jackpotPerc'   - The percentage of rewards in which a jackpot is
    %                   delivered (i.e a long duration reward)
    % 'jackpotDur'     - The duration of the jackpot duration.
    %
    % The regular duration (i.e. non-jackpot) of the reward is specified per item
    % using the add() function of the feedback parent class.
    %
    
    properties
        nrDelivered = 0;
        totalDelivered = 0;
        tmr; % Timer to control duration
    end
    
    methods (Access=public)
        function o=liquid(c,name)
            if nargin<2
                name = 'liquid';
            end
            o=o@neurostim.plugins.feedback(c,name);
            o.addProperty('device','mcc');
            o.addProperty('deviceFun','digitalOut');
            o.addProperty('deviceChannel',1);
            o.addProperty('jackpotPerc',1);
            o.addProperty('jackpotDur',1000);
            
        end
        
        function beforeExperiment(o)
            
            %Check that the device is reachable
            if any(hasPlugin(o.cic,o.device))
                %Iniatilise to the closed state.
                close(o);
            else
                o.cic.error('CONTINUE',['Liquid reward added but the ' o.device ' device could not be found.']);
                o.device = 'FAKE';
            end
        end
        
        
    end
    
    methods (Access=protected)
        
        function chAdd(o,varargin)
            p = inputParser;
            p.StructExpand = true; % The parent class passes as a struct
            p.addParameter('duration',Inf);
            p.parse(varargin{:});
            
            % store the duration
            o.addProperty(['item', num2str(o.nItems), 'duration'],p.Results.duration);
        end
        
        function deliver(o,item)
            % Responds by calling the device (through the device fun) to activate liquid reward.
            % This assumes that the device function has the arguments :
            % (channel, value).
            % Not that Mcc and Trellis devices use a Matlab timer to handle the "duration" aspect - this could be inaccurate or interrupt
            % time-sensitive functions. So best not to use this in the  middle of a trial
            duration = o.(['item', num2str(item) 'duration']);
            if ~strcmpi(o.device,'FAKE')
                if rand*100<o.jackpotPerc
                    o.writeToFeed('Jackpot!!!')
                    duration = o.jackpotDur;
                end
                open(o,duration);
                %Keep track of how much has been delivered.
                o.nrDelivered = o.nrDelivered + 1;
                o.totalDelivered = o.totalDelivered + duration;
            else
                o.writeToFeed(['Fake liquid reward delivered (' num2str(duration) 'ms)']);
            end
        end
        
        function open(o,duration)
            if ischar(o.deviceFun)
                feval(o.deviceFun,o.cic.(o.device),o.deviceChannel,true,duration);
            elseif isa(o.deviceFun,'function_handle')
                o.deviceFun(o.deviceChannel,true,duration);
            else
                error('Char or function_handle for deviceFun only')
            end
        end
        
        function close(o)
            if ischar(o.deviceFun)
                feval(o.deviceFun,o.cic.(o.device),o.deviceChannel,false);
            elseif isa(o.deviceFun,'function_handle')
                o.deviceFun(o.deviceChannel,false);
            else
                error('Char or function_handle for deviceFun only')
            end
        end
        
        function report(o)
            %Provide an update of performance to the user.
            o.writeToFeed(horzcat('Delivered: ', num2str(o.nrDelivered), ' (', num2str(round(o.nrDelivered./o.cic.trial,1)), ' per trial); Total duration: ',num2str(o.totalDelivered)));
        end
    end
    
    
    %%  GUI functions
    methods (Access= public)
        function guiSet(o,parms)
            % This is the function called when the experiment is
            % initialized and whenever any of the (tagged) values in the
            % gui panel (see guiLayout) change.
            o.jackpotDur = parms.JackpotDur;
            o.jackpotPerc = parms.JackpotPerc;
            makeSticky(o,'jackpotDur');
            makeSticky(o,'jackpotPerc');
            % Currently this only works for a single liquid reward item.
            % This function is called before the experiment file starts so
            % the item has not been defined yet.  The user has to use the 
            % output of nsGui.parse to set the value in the experiment
            % file.
        end
    end
    
    
    methods (Static)
        function valueChangedCb(h,event)    
            if isfield(h.Parent.UserData,'plugin')
                plg = h.Parent.UserData.plugin;
                switch (h.Tag)
                    case 'Duration'
                        % If we change the value in the gui we presumably
                        % intend for this to stick  (jackpot is sticky
                        % already as it is defined before experiment
                        % starrt).
                        makeSticky(plg,'item1duration');            
                         plg.item1duration = event.Value;
                    case 'JackpotDur'                        
                        plg.jackpotDur  = event.Value;                        
                    case 'JackpotPerc'
                        plg.jackpotPerc  = event.Value;                        
                    otherwise
                        
                end
            end
        end

        function guiLayout(p)
            % Add plugin specific elements
            % The Tags chosen here must match the field names used in guiSet
            
            h = uilabel(p);
            h.HorizontalAlignment = 'left';
            h.VerticalAlignment = 'bottom';
            h.Position = [100 39 50 22];
            h.Text = 'Reward';
            
            
            h = uieditfield(p, 'numeric','Tag','Duration'); % Must be text to allow vectors.
            h.Position = [100 17 50 22];
            h.Value= 200;
            h.ValueChangedFcn = @neurostim.plugins.liquid.valueChangedCb;

            h = uilabel(p);
            h.HorizontalAlignment = 'left';
            h.VerticalAlignment = 'bottom';
            h.Position = [155 39 50 22];
            h.Text = 'Jackpot';
            h.ValueChangedFcn = @neurostim.plugins.liquid.valueChangedCb;

            h = uieditfield(p, 'numeric','Tag','JackpotDur');
            h.Value = 1000;
            h.Position = [155 17 50 22];
            h.ValueChangedFcn = @neurostim.plugins.liquid.valueChangedCb;
            
            
            h = uilabel(p);
            h.HorizontalAlignment = 'left';
            h.VerticalAlignment = 'bottom';
            h.Position = [210 39 50 22];
            h.Text = '%Jackpot';
            h = uieditfield(p, 'numeric','Tag','JackpotPerc');
            h.Value = 0.01;
            h.Position = [210 17 50 22];
            
        end
        
    end
end