classdef gitTracker < neurostim.plugin
% Git Interface for PTB
% 
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
            o.addProperty('BLA','BLA');
        end
        
        
        
        function beforeExperiment(o,c,evt)
            % Before the experiment starts we check that all changes have
            % been committed. The unique identifier for the committed code
            % (i.e. the experiment code that actually ran) is added to the
            % log.
            
        end
    end
    
end