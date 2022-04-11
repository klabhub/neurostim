%{
# Mask Classification Type
      ->  MaskClassification
        -> Segmentation.Mask
        ---
        -> MaskType
        confidence=null: float  
%}
classdef MaskClassificationType < dj.Part
    methods
        function make(self, key)
        end
    end
end
