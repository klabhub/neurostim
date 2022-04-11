%{
#  Parameter set used for processing of calcium imaging data
    paramset_idx:  smallint
    ---
    -> ProcessingMethod
    paramset_desc: varchar(128)
    param_set_hash: uuid
    unique index (param_set_hash)
    params: longblob  # dictionary of all applicable parameters
%}
classdef ProcessingParamSet < dj.Lookup
    methods (Access=public )

        function insert_new_params(cls, processing_method, paramset_idx,paramset_desc, params)
            param_dict = struct('processing_method', processing_method,...
                'paramset_idx', paramset_idx,...
                'paramset_desc', paramset_desc,...
                'params', params,...
                'param_set_hash', dict_to_uuid(params));

            q_param = cls & {'param_set_hash',param_dict.param_set_hash};

            if exists(q_param)
                pname = q_param.fetch1('paramset_idx');
                if pname == paramset_idx
                    % If the existed set has the same name: job done
                    return
                else
                    %If not same name: human error, trying to add the same paramset with different name
                    error(dj.DataJointError(sprintf('The specified param-set already exists - name: %s',pname)));
                end
            else
                insert1(cls,param_dict)
            end
        end
    end
end