%{
# Manual table for defining a processing task ready to be run

    -> scan.Scan
    -> ProcessingParamSet
    ---
    processing_output_dir: varchar(255)         #  output directory of the processed scan relative to root data directory
    task_mode='load': enum('load', 'trigger')   # 'load': load computed analysis results, 'trigger': trigger computation
%}
classdef ProcessingTask < dj.Manual
    methods (Access=public)

        function infer_output_dir(cls, scan_key,  relative, mkdir)
            %         image_locators = {'NIS': get_nd2_files, 'ScanImage': get_scan_image_files, 'Scanbox': get_scan_box_files}
            %         image_locator = image_locators[(scan.Scan & scan_key).fetch1('acq_software')]
            %
            %         scan_dir = find_full_path(get_imaging_root_data_dir(), image_locator(scan_key)[0]).parent
            %         root_dir = find_root_directory(get_imaging_root_data_dir(), scan_dir)
            %
            %         paramset_key = ProcessingParamSet.fetch1()
            %         processed_dir = pathlib.Path(get_processed_root_data_dir())
            %         output_dir = (processed_dir
            %                 / scan_dir.relative_to(root_dir)
            %                 / f'{paramset_key["processing_method"]}_{paramset_key["paramset_idx"]}')
            %
            %         if mkdir:
            %             output_dir.mkdir(parents=True, exist_ok=True)
            %
            %         return output_dir.relative_to(processed_dir) if relative else output_dir
        end


        function auto_generate_entries(cls, scan_key, task_mode)
            % Method to auto-generate ProcessingTask entries for a particular Scan using a default paramater set.

            %
            %         default_paramset_idx = os.environ.get('DEFAULT_PARAMSET_IDX', 0)
            %
            %         output_dir = cls.infer_output_dir(scan_key, relative=False, mkdir=True)
            %
            %         method = (ProcessingParamSet & {'paramset_idx': default_paramset_idx}).fetch1('processing_method')
            %
            %         try:
            %             if method == 'suite2p':
            %                 from element_interface import suite2p_loader
            %                 loaded_dataset = suite2p_loader.Suite2p(output_dir)
            %             elif method == 'caiman':
            %                 from element_interface import caiman_loader
            %                 loaded_dataset = caiman_loader.CaImAn(output_dir)
            %             else:
            %                 raise NotImplementedError('Unknown/unimplemented method: {}'.format(method))
            %         except FileNotFoundError:
            %             task_mode = 'trigger'
            %         else:
            %             task_mode = 'load'
            %
            %         cls.insert1({
            %             **scan_key, 'paramset_idx': default_paramset_idx,
            %             'processing_output_dir': output_dir, 'task_mode': task_mode})
        end
    end
end