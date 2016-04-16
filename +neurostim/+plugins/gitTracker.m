classdef gitTracker < neurostim.plugin
% Git Interface for PTB
% 
% The idea:
% A laboratory forks the GitHub repo to add their own experiments
% in the experiments folder.  These additions are only tracked in the
% forked repo, so the central code maintainer does not have to be bothered
% by it. The new laboratory can still contribute to the core code, by
% making changes and then sending pull requests.
% 
% The goal of the gitTracker plugin is to log the state of the entire repo
% for a particular laboratory at the time an experiment is run. It checks
% whether there are any uncommitted changes, and asks/forces them to be
% committed before the experiment runs. The hash corresponding to the final
% commit is stored in the data file such that the complete code state can
% easily be reproduced later. 
% 
% BK  - Apr 2016   
    
    properties (Access=public)
    end
    
    properties (Dependent)
        gitVersion; % OS installed version of git.
    end
    
    methods
        function v= get.gitVersion(o) 
              [status,txt] = system('git --version');
                if status==0
                    match = regexp(txt,'git version (?<version>\d\.\d\.\d)\w*','names');
                    v=match.version;
                else
                    v= NaN;
                end
        end
    end
    methods
        function o= gitTracker(c)
            o = o@neurostim.plugin(c,'gitTracker'); 
            if ~exist('git.m','file')
                error('The gitTracker class depends on a wrapper for git that you can get from github.com/manur/MATLAB-git');
            end
            
            if isnan(o.gitVersion)
                error('gitTracker requires git. Please install it first.');
            end
            
            o.listenToEvent('BEFOREEXPERIMENT');
            o.addProperty('silent',false,@islogical); % Do a silent commit if needed
            o.addProperty('push',false,@islogical); % Force a push to the remote repo.
            o.addProperty('hash',NaN); % The hash-key of the committed code. 
        end
        
        
        
        function beforeExperiment(o,c,evt)
            % Before the experiment starts we check that all changes have
            % been committed. The unique identifier for the committed code
            % (i.e. the experiment code that actually ran) is added to the
            % log.
            
            [txt,status] = git('status');
            changes = regexp(txt,'(?<mods>\<modified:.+)no changes added','names');
           nrMods = numel(strfind(txt,'modified:'));
           
            if nrMods>0
                disp([num2str(nrMods) ' files have changed. These have to be committed before running this experiment']);
                disp(changes.mods);
                if o.silent
                    msg = ['Silent commit before experiment ' datestr(now,'yyyy/mm/dd HH:MM:SS')]);
                else
                    msg = input('Code has changed. Please provide a commit message','s');
                end
               [txt,status]=  git(['commit -a -m ''' msg '''']);
               if status >0
                   error('File commit failed.');
               end
            end
        end
    end
    
end