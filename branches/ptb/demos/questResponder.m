classdef questResponder < neurostim.plugin;
    properties
        simulatedThreshold = [-2 -3 -1 -0.5];
        simulate = true; % Simulate responses
    end
    methods
        function o = questResponder
            o = o@neurostim.plugin('questResponder');  
            o.keyStrokes ={'z', '/'};
        end
        
        function afterFrame(o,frame)
            if o.simulate && frame==1
                % On the 10th frame, simulate an all-knowing observer. Of
                % course you would not have to do this in a real
                % experiment. Instead you'd use the keyboard function below
                % to generate responses
                response=QuestSimulate(o.cic.lldots.quest.q(o.cic.condition),o.cic.lldots.coherence,o.simulatedThreshold(o.cic.condition));
                answer(o.cic.lldots,(response));
                o.nextTrial;
            end
        end
        
        function keyboard(o,key,time)
            switch (key)
                case 'z'
                    % User responded leftward
                    correct= (o.lldots.direction==0);
                case 'l'
                    % User responded rightward
                    correct = (o.lldots.direction ==180);
                otherwise
                    error('?')
            end
            answer(o.cic.lldots,correct);                    
        end
    end
end