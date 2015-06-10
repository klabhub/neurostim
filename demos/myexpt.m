classdef myexpt < neurostim.plugin
    % A user could define a simple plugin like this one to control all
    % aspects of an experiment. The need for this, however, is limited as
    % almost (?) the same functionality can be generated with the
    % cic.addScript method which essentially allows the user to provide
    % only functions that serve as the member functions of a plugin class. 
    
    
    methods
        function o = myexpt
            o = o@neurostim.plugin('myexpt');
            o.listenToEvent({'AFTERFRAME'});
            o.listenToKeyStroke({'z','p'},{'nxt trial','y =60'});
        end
        
        
        
        function afterFrame(o,c,evt)            
            if iseven(floor(c.frame/30))
                c.gabor.orientation = 30;
            else
                c.gabor.orientation = -30;
            end
            
        end
        
        % Keyboard handling, separate from the stimuli in use. (but with
        % access to the stimuli)
        function keyboard(o,key,time)
            switch upper(key)
                case 'Z'
                    %write
                    o.cic.fix.color = []
                case 'P'
                    o.cic.fix.Y = 60;                                        
            end
            
        end
    end
end