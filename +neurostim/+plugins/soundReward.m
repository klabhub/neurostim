classdef soundReward < neurostim.plugins.reward
    properties
        soundCorrectFile;
        soundIncorrectFile;
        soundCorrect;
        soundIncorrect;
        correctBuffer;
        incorrectBuffer;
    end
    
    properties (Access=private)
        paHandle;
    end
    
    methods (Access=public)
        function o=soundReward(name)
            o=o@neurostim.plugins.reward(name);
            o.soundCorrectFile = 'nsSounds\sounds\correct.wav';
            o.soundIncorrectFile = 'nsSounds\sounds\incorrect.wav';
        end
        
        function beforeExperiment(o,c,evt)
            % Sound initialization
            InitializePsychSound(1);
            o.paHandle = PsychPortAudio('Open');
            [y,~] = audioread(o.soundCorrectFile);
            
            if size(y,2) == 1
                o.soundCorrect = [y'; y'];
            else
                o.soundCorrect = y';
            end
            
            [y,~] = audioread(o.soundIncorrectFile);
            
            if size(y,2) == 1
                o.soundIncorrect = [y'; y'];
            else
                o.soundIncorrect = y';
            end
            
            % store correct and incorrect sounds in pre-allocated buffers
            o.correctBuffer = PsychPortAudio('CreateBuffer',o.paHandle,o.soundCorrect);
            o.incorrectBuffer = PsychPortAudio('CreateBuffer',o.paHandle,o.soundIncorrect);
            
        end
        
        function afterExperiment(o,c,evt)
            PsychPortAudio('Close', o.paHandle);
        end
        
        function afterTrial(o,c,evt)
            if isstruct(o.queue)
                a=strcmpi({o.queue.when},'AFTERTRIAL');
                if any(a)
                    % if any behavior was wrong, play the incorrect sound
                    if any([o.queue(a).response] == 0)
                        o.activateReward(false);
                    else % otherwise, play correct sound.
                        o.activateReward(true);
                    end
                    o.queue(a) = [];
                end
            end
        end
    end
    
    methods (Access=protected)
        
        function activateReward(o,response,varargin)
           % function activateReward(o,response)
           % Fills buffer with sound and conducts immediate playback.
           % Inputs:
           % response - true/false, indicates whether to give a correct or
           % incorrect sound response.
           if response
               PsychPortAudio('FillBuffer', o.paHandle,o.correctBuffer);
           else
               PsychPortAudio('FillBuffer', o.paHandle, o.incorrectBuffer);
           end
           % play sound immediately.
           PsychPortAudio('Start',o.paHandle);
        end
       
        
        
    end
        
    
    
end