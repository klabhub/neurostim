%{
#  Different rounds of curation performed on the processing results of the imaging data (no-curation can also be included here)
    -> Processing
    curation_id: int
    ---
    curation_time: datetime             # time of generation of this set of curated results 
    curation_output_dir: varchar(255)   # output directory of the curated results, relative to root data directory
    manual_curation: bool               # has manual curation been performed on this result?
    curation_note='': varchar(2000)  
%}
classdef Curation <dj.Manual
    methods (Access= public)
        function create1_from_processing_task(self, key, is_curated, curation_note)
            %        A convenient function to create a new corresponding "Curation" for a particular "ProcessingTask"
            %         if key not in Processing():
            %             raise ValueError(f'No corresponding entry in Processing available for: {key};'
            %                              f' do `Processing.populate(key)`')
            %
            %         output_dir = (ProcessingTask & key).fetch1('processing_output_dir')
            %         method, imaging_dataset = get_loader_result(key, ProcessingTask)
            %
            %         if method == 'suite2p':
            %             suite2p_dataset = imaging_dataset
            %             curation_time = suite2p_dataset.creation_time
            %         elif method == 'caiman':
            %             caiman_dataset = imaging_dataset
            %             curation_time = caiman_dataset.creation_time
            %         else:
            %             raise NotImplementedError('Unknown method: {}'.format(method))
            %
            %         # Synthesize curation_id
            %         curation_id = dj.U().aggr(self & key, n='ifnull(max(curation_id)+1,1)').fetch1('n')
            %         self.insert1({**key, 'curation_id': curation_id,
            %                       'curation_time': curation_time, 'curation_output_dir': output_dir,
            %                       'manual_curation': is_curated,
            %                       'curation_note': curation_note})
        end
    end
end
