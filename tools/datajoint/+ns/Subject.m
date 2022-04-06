%{
# Subject information
subject: varchar(50) # Code or number that identifies a subject 
---
sex = NULL : enum('M','F')          # biological sex
gender = NULL : enum('M','F','N')  # gender 
dob = NULL : date                   # date of birth (ISO 8601)
species = NULL : enum('Human','Mouse','Macaque') # Species
%}
% BK  - April 2022
classdef Subject < dj.Manual

    methods (Access=public)
        function updateFromFile(tbl, file,newOnly)
            % Update the subjects table by reading information from a file.
            % This example works for the CSV spreadsheet that Klab
            % maintains for its subjects.
            % INPUT
            % tbl  - The subjects table (or a subset)
            % file - The file to read
            % newOnly  - Update only subjects whose species is currently
            %               not set.

            if ~exist(file,'file')
                error('No such file %s',file)
            end
            if nargin <3 
                newOnly = true;
            end

            T = readtable(file);
            for key = tbl.fetch()'
                if newOnly && ~isempty(fetch1(tbl & key,'species'))
                    continue;
                end
                % Loop over all subjects in the databse
                stay = T.KLabNumber==str2double(key.subject);
                if any(stay)
                    tuple = {'gender',T.Gender{stay}(1),'species','Human','dob',datestr(T.DateOfBirth(stay),'yyyy-mm-dd')};
                    for i=1:2:numel(tuple)
                        update(tbl & key,tuple{i},tuple{i+1});
                    end
                    fprintf('Updated %s \n', key.subject);
                else
                    fprintf('No match found for subject %s\n',key.subject)
                end
            end
        end
    end
end