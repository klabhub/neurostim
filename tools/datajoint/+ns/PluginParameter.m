%{
# A class representing a Neurostim parameter/property
-> ns.Plugin
property_name : varchar(25)     # The name of the neurostim.parameter
---
property_value = NULL : longblob    # The value(s) of the constant/trial parameter/event 
property_time = NULL : longblob     # Time at which the event occured
property_type : enum('Global','Parameter','Event','ByteStream') # Type of parameter
%}
% Global type have a single value in an experiment
% Parameter type have a single value per trial
% Event type have values that (can) change inside a trial. The time at which they occur is usually most relevant.
% ByteStream type are parameters that could not be stored "as is" in the
% database (e.g. objects) - They are converted to a byte stream and then
% stored. 
% See Experiment.get how parameters can be retrieved from the
% database.
% 
% BK - April 2022
classdef PluginParameter < dj.Part
    properties (SetAccess = protected)
        master = ns.Plugin;  % Part  table for the plugin
    end

    methods (Access= ?ns.Plugin)
        function make(self,key,prm)
            % Called from ns.Plugin to fill the parameter values
            assert(isa(prm,'neurostim.parameter'),'PluginParameter needs a neurostim.parameter object as its input.');

            time =[];
            if prm.cntr==1
                % Single value: global property
                % Easy: store only this value
                type = 'Global';
                value =prm.value;
            elseif prm.changesInTrial
                % Changes within a trial : event
                % Store all values, plus the time at which the event
                % occurred.
                type = 'Event';
                [value,~,~,time] =get(prm,'matrixIfPossible',true);
            else
                % One value per trial : parameter
                % Retreive the value at the end of the trial (as that
                % should be the one used throughout).
                type = 'Parameter';
                [value,~,~,time] = get(prm,'atTrialTime',Inf,'matrixIfPossible',true,'withDataOnly',false);
                % Some cleanup to store the values in the database
                if iscell(value)
                    %Replace function handles with strings
                    isFun = cellfun(@(x) (isa(x,'function_handle')),value);
                    [value(isFun)] = cellfun(@func2str,value(isFun),'UniformOutput',false);
                end
                % Neurostim should only store changing values, but that
                % did not always work perfectly. Here we detect values that
                % were really constant so that we can store a single value
                % for the experiment (i.e. Global type).
                if iscellstr(value)  || ischar(value) || isstring(value) || isnumeric(value) || islogical(value)
                    if iscellstr(value) %#ok<ISCLSTR> 
                        uValue=  unique(value);
                        if size(uValue,1)==1
                            uValue= uValue{1}; % Get rid of cell
                        end
                    elseif ismatrix(value) 
                        uValue=  unique(value,'rows');                       
                        if isnumeric(value) && all(isnan(value(:)))
                            % A vector with all nans  
                            uValue =NaN;
                        end
                    else % it is something >2D
                        uValue = nan(2,1); % Just a flag to skip the next part
                    end
                    if size(uValue,1)==1
                        % Really only one value
                        value = uValue;
                        type = 'Global';
                        time = [];
                    end
                end
            end

            if isstruct(value) && numel(fieldnames(value))==0
                value = true(size(value));
            end


            key.property_name = prm.name;
            key.property_value = value;
            key.property_type = type;
            key.property_time = time;
            try
                self.insert(key);
            catch me
                if contains(me.message,'Duplicate entry')
                    key.property_name = [key.property_name key.property_name];
                    self.insert(key)
                elseif contains(me.message,'Matlab placeholder') || contains(me.message,'unsupported type')
                    % Database could not store this value. Probably some
                    % kind of object. Convert to byte stream, the user can
                    % get the value by using getArrayFromByteStream if
                    % really needed,  at least in
                    % Matlab (see Experiment.get), 
                    key.property_value = getByteStreamFromArray(value);
                    key.property_type = 'ByteStream';
                    self.insert(key);
                else
                    rethrow(me)
                end
            end
        end

    end


end



