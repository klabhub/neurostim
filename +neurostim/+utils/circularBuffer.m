%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%% -BRIEF DESCRIPTION:
% * Vector subclass from Built in class 'double'.
%
%%%% -DETAILED DESCRIPTION:
% * If 'a' is an object of circularBuffer, then 'a(i)' is accessed as 'a(rem(i,length(a)))'
% * circularBuffer objects are always treated just like matrix/vector in matlab.
%
%%%% -OPTIONS:
%
%%%% -EXAMPLES:
% 1. To create a circular buffer vector with 3 elements
%       a = circularBuffer([1,2,3]);
% 2. To create circular buffer matrix
%       b = circularBuffer([1,2;3,4]);
% 2. To convert a vector/matrix to circular buffer
%       c = [1,2;3,4];
%       d = circularBuffer(c);
%
%%%% -NOTES:
% * All MATLAB matrix/vector operations are also applicable for circular buffer objects.
%
%%%% -NOTES (Programming):
%
%%%% -TODO:
%
%%%% -Versions
%   Version 1 release: 7 August 2015 
%
%%%% -Author
%   Anver Hisham <anverhisham@gmail.com>
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% In use by neurostim.plugins.mdaq


%{
Copyright (c) 2015, Anver Hisham
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are
met:

    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in
      the documentation and/or other materials provided with the distribution

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
POSSIBILITY OF SUCH DAMAGE.
%}
%% -
classdef circularBuffer < double
    
    methods
        function obj = circularBuffer(data)
            obj = obj@double(data);     %% -NOTE: This kind of construction prevents any properties defined inside this class!!
        end
       
        function out = subsref(obj,s)
            switch s(1).type
                case '()'
                    objDouble = double(obj);
                    %%%%%%%%%%%% -Create Proper Indices- %%%%%%%%%%%%
                    sizePerDimension = size(objDouble);
                    %% -If Object is Column/Row vector, then make all elements in sizePerDimension to max dimension
                    if(numel(sizePerDimension)<=2 && min(sizePerDimension)==1)
                        sizePerDimension = max(sizePerDimension);
                    end
                    %% -For single input, access the matrix object as a vector
                    if(numel(s(1).subs)==1)
                        sizePerDimension = numel(objDouble);
                    end
                    if(numel(s(1).subs)>numel(sizePerDimension))
                     % BK removed error to allow buffer(1,:) even for a single column
                     % error('Error(circularBuffer): Index exceeds matrix dimensions.');
                    end
                    %% -Iterate for each input element,
                    ind = s(1).subs;
                    for i=1:numel(ind)
                        if(~strcmp([s(1).subs{i}],':'))
                            ind{i} = mod(s(1).subs{i}-1,sizePerDimension(i))+1;  
                        end
                    end
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    out = objDouble(ind{:});
                otherwise
                    error(['Error(circularBuffer): Use bracket always... Currently used ',s(1).type,' !!!']);
            end
        end
       
      function obj = subsasgn(obj,s,input)
           switch s(1).type
               case '()'
                objDouble = double(obj);                            %% -TODO: For Speeding up, entire object conversion should be avoided ...
                    %%%%%%%%%%%% -Create Proper Indices- %%%%%%%%%%%%
                    sizePerDimension = size(objDouble);
                    %% -If Object is Column/Row vector, then make all elements in sizePerDimension to max dimension
                    if(numel(sizePerDimension)<=2 && min(sizePerDimension)==1)
                        sizePerDimension = max(sizePerDimension);
                    end
                    %% -For single input, access the matrix object as a vector
                    if(numel(s(1).subs)==1)
                        sizePerDimension = numel(objDouble);
                    end
                    if(numel(s(1).subs)>numel(sizePerDimension))
                        %BK removed error('Error(circularBuffer): Index exceeds matrix dimensions.');
                    end
                    %% -Iterate for each input element,
                    ind = s(1).subs;
                    for i=1:numel(ind)
                        if(~strcmp([s(1).subs{i}],':'))
                            ind{i} = mod(s(1).subs{i}-1,sizePerDimension(i))+1;  
                        end
                    end
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                objDouble(ind{:}) = input;
                obj = circularBuffer(objDouble);
               otherwise
                   error(['Error(circularBuffer): Use bracket always... Currently used ',s(1).type,' !!!']);
           end
      end
       
   end
end