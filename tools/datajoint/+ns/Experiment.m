%{
# An experiment refers to a single run of a specific experimental paradigm
starttime: time # Time that the experiment started (HH:MM:SS)
-> ns.Session   # Corresponding session session  (FK)
---
paradigm: varchar(255)      # Name of the paradigm
file = NULL : varchar(255)  # File that contains the Neurostim output
stimuli = NULL : smallint      # Number of stimuli in the experiment
blocks = NULL : smallint       # Number of blocks in the experiment
conditions = NULL : smallint   # Number of conditions 
trials = NULL : smallint       # Number of trials 
matlab = NULL : varchar(100)  # Matlab version used to run the experiment
ptb = NULL: varchar(100)     # Psychtoolbox version used to run the experiment
ns = NULL  : varchar(100)   # Neurosti version used to run the experiment
run = NULL : smallint       # How many times this subject has run this experiment
seq = NULL : smallint       # The sequential recruitment number of this subject for this experiment
%}
%
% BK - April 2022.

classdef Experiment  < dj.Manual
    methods (Access = public)
        function [out,filename] = get(tbl,plg)
            % function [out,filename] = get(o,plg)
            % Retrieve all information on a specific plugin in an experiment
            %
            % INPUT
            % o - A ns.Experiment table with at least 1 row (i.e. one
            %           experiment)
            % plg - The name of the plugin
            % OUTPUT
            % out -  A struct with all global constants (i.e. those that do
            % not change within an experiment), parameters (a single value per
            % trial that does not change within a trial), and events (which can
            % happen at any time).
            % filename - The file that originally provided these values to the
            % database.
            %
            if ~exists(tbl)
                out = struct([]);
                filename = '';
                return;
            end
            if nargin<2
                plg = {};
            elseif ischar(plg)
                plg = {plg};
            end

            ix =1:count(tbl);
            out = cell(numel(ix),1);
            filename = cell(numel(ix),1);
            cntr =0;
            for key=tbl.fetch()'
                cntr = cntr + 1;
                filename{cntr} = fetch1(tbl &key,'file');               
                if nargin <2 || isempty(plg) 
                    % Get info from all plugins
                    plg  = fetchn( (tbl & key) * ns.Plugin,'plugin_name');
                end
                v= [];
                for p = 1:numel(plg)
                    plgName = plg{p};
                    % Get the properties for this plugin
                    props = (tbl & key) * ns.Plugin * ns.PluginParameter & ['plugin_name=''' plgName ''''] ;
                    % Global consts.
                    [vals,names] = fetchn(props & 'property_type=''Global''' ,'property_value','property_name');
                    tmp = cell(1,2*numel(names));
                    [tmp{1:2:end}] =deal(names{:});
                    [tmp{2:2:end}] = deal(vals{:});
                    v.(plgName) = struct(tmp{:});
                    % Parameters - they do not change within a trial. The
                    % output struct will have a vector/cell with one value for
                    % each trial

                    % Events - these can happen at any time. The struct
                    % contains both the values and the times at which they
                    % occurred (e.g. v.X and v.XTime)
                  
                    %Bytestream - can contain objects, coded as bytes.
                    % Decode here.

                    [vals,names,times,trials,types] = fetchn(props - 'property_type =''Global''' ,'property_value','property_name','property_time','property_trial','property_type');
                    for j=1:numel(names)
                        if strcmpi(types(j),'ByteStream')
                             v.(plgName).(names{j}) =getArrayFromByteStream(vals{j});
                        else
                        v.(plgName).(names{j}) =vals{j};
                        end
                        v.(plgName).([names{j} 'Time']) = times{j};
                        v.(plgName).([names{j} 'Trial']) = trials{j};

                    end
                    

                end
                if isempty(v)
                    fprintf('No data found for %s \n',filename{cntr});
                else
                    out{cntr} = v;
                end
            end

            % Convenience; remove the wrappping cell if it only a single
            % experiment was queried.
            if numel(ix)==1
                out = out{1};
                filename=filename{1};
            end
        end


        function updateWithFileContents(tbl,oldKey,newOnly)
            % function updateWithFileContents(self,oldKey,newOnly)
            % Read neurostim files to fill the database with the
            % information contained in plugins/stimuli. This can be done
            % automatically (by ns.scan), or manually to update information
            % INPUT
            % tbl - (A subset of) the ns.Experiment table to update.
            % oldKey - The primary key of the experiment to update (if not
            % specified or empty, all experiments in tbl will be updated).
            % newOnly  - Set to true to update only those experiments that
            % have no information in the database currently. [true]
            
            if nargin <3
                newOnly = true;
            end
            if nargin<2 || isempty(oldKey)
                % Run all
                for key=tbl.fetch()'
                    updateWithFileContents(tbl,key,newOnly);
                end
                return;
            end
            % Check if this eperiment already has file data, if newOnly
            % is true, we skip those.
            if newOnly && exists(tbl & oldKey) && ~isnan(fetchn(tbl & oldKey,'stimuli'))
                return;
            end

            % Read the file to add details
            if isfield(oldKey,'file')
                file = oldKey.file;
            else
                file = fetch1(tbl & oldKey, 'file');
            end

            load(file,'c');
            actualNrTrialsStarted = max([c.prms.trial.log{:}]);
            if actualNrTrialsStarted <1
                fprintf('Skipping %s - no completed trials\n',file);
                return
            end

            % Pull the top level information to put in the tbl
            tuple = {'stimuli',c.nrStimuli,'blocks',c.nrBlocks,...
                'conditions',c.nrConditions,'trials',actualNrTrialsStarted,...
                'matlab',c.matlabVersion,'ptb',c.ptbVersion.version,...
                'ns','somehash','run',c.runNr,'seq',c.seqNr};
            if ~exists(tbl & oldKey)
                insert(tbl,oldKey)
            end
            % Then update
            for i=1:2:numel(tuple)
                update(tbl & oldKey,tuple{i:i+1}); %Updated version
            end
            % Remove the current plugin info.
            if exists(ns.Plugin & oldKey)
                del(ns.Plugin & oldKey)
            end
            % re-add each plugin (pluginOrder includes stimuli)
            for plg = [c.pluginOrder c]
                plgKey = struct('starttime',oldKey.starttime,'session_date',oldKey.session_date,'subject',oldKey.subject);
                make(ns.Plugin,plgKey,plg);
            end
        end

    end

end
