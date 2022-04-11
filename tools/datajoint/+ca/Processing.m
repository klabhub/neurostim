%{
# Processing Procedure
-> ProcessingTask
    ---
    processing_time     : datetime  # time of generation of this set of processed, segmented results
    package_version=''  : varchar(16)
    
%}
classdef Processing < dj.Computed
    properties (Dependent)
        key_source
    end

    methods
        function v= get.key_source(o)
            % Run processing only on Scan with ScanInfo inserted
            v= ca.ProcessingTask & ca.scan.ScanInfo;
        end
    end

    methods
        function make(self, key)
%         task_mode = (ProcessingTask & key).fetch1('task_mode')
% 
%         output_dir = (ProcessingTask & key).fetch1('processing_output_dir')
%         output_dir = find_full_path(get_imaging_root_data_dir(), output_dir).as_posix()
%         if not output_dir:
%             output_dir = ProcessingTask.infer_output_dir(key, relative=True, mkdir=True)
%             # update processing_output_dir
%             ProcessingTask.update1({**key, 'processing_output_dir': output_dir.as_posix()})
%         
%         if task_mode == 'load':
%             method, imaging_dataset = get_loader_result(key, ProcessingTask)
%             if method == 'suite2p':
%                 if (scan.ScanInfo & key).fetch1('nrois') > 0:
%                     raise NotImplementedError(f'Suite2p ingestion error - Unable to handle'
%                                               f' ScanImage multi-ROI scanning mode yet')
%                 suite2p_dataset = imaging_dataset
%                 key = {**key, 'processing_time': suite2p_dataset.creation_time}
%             elif method == 'caiman':
%                 caiman_dataset = imaging_dataset
%                 key = {**key, 'processing_time': caiman_dataset.creation_time}
%             else:
%                 raise NotImplementedError('Unknown method: {}'.format(method))
%         elif task_mode == 'trigger':
%             
%             method = (ProcessingTask * ProcessingParamSet * ProcessingMethod * scan.Scan & key).fetch1('processing_method')
% 
%             if method == 'suite2p':
%                 import suite2p
% 
%                 suite2p_params = (ProcessingTask * ProcessingParamSet & key).fetch1('params')
%                 suite2p_params['save_path0'] = output_dir
%                 suite2p_params['fs'] = (ProcessingTask * scan.Scan * scan.ScanInfo & key).fetch1('fps')
% 
%                 image_files = (ProcessingTask * scan.Scan * scan.ScanInfo * scan.ScanInfo.ScanFile & key).fetch('file_path')
%                 image_files = [find_full_path(get_imaging_root_data_dir(), image_file) for image_file in image_files]
% 
%                 input_format = pathlib.Path(image_files[0]).suffix
%                 suite2p_params['input_format'] = input_format[1:]
%                 
%                 suite2p_paths = {
%                     'data_path': [image_files[0].parent.as_posix()],
%                     'tiff_list': [f.as_posix() for f in image_files]
%                 }
% 
%                 suite2p.run_s2p(ops=suite2p_params, db=suite2p_paths)  # Run suite2p
% 
%                 _, imaging_dataset = get_loader_result(key, ProcessingTask)
%                 suite2p_dataset = imaging_dataset
%                 key = {**key, 'processing_time': suite2p_dataset.creation_time}
% 
%             elif method == 'caiman':
%                 from element_interface.run_caiman import run_caiman
% 
%                 tiff_files = (ProcessingTask * scan.Scan * scan.ScanInfo * scan.ScanInfo.ScanFile & key).fetch('file_path')
%                 tiff_files = [find_full_path(get_imaging_root_data_dir(), tiff_file).as_posix() for tiff_file in tiff_files]
% 
%                 params = (ProcessingTask * ProcessingParamSet & key).fetch1('params')
%                 sampling_rate = (ProcessingTask * scan.Scan * scan.ScanInfo & key).fetch1('fps')
% 
%                 ndepths = (ProcessingTask * scan.Scan * scan.ScanInfo & key).fetch1('ndepths')
% 
%                 is3D = bool(ndepths > 1)
%                 if is3D:
%                     raise NotImplementedError('Caiman pipeline is not capable of analyzing 3D scans at the moment.')
%                 run_caiman(file_paths=tiff_files, parameters=params, sampling_rate=sampling_rate, output_dir=output_dir, is3D=is3D)
% 
%                 _, imaging_dataset = get_loader_result(key, ProcessingTask)
%                 caiman_dataset = imaging_dataset
%                 key['processing_time'] = caiman_dataset.creation_time
% 
%         else:
%             raise ValueError(f'Unknown task mode: {task_mode}')
% 
%         self.insert1(key)
        end
    end
end
