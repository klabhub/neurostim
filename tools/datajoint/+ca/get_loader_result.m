






function get_loader_result(key, table):
%     """
%     Retrieve the loaded processed imaging results from the loader (e.g. suite2p, caiman, etc.)
%         :param key: the `key` to one entry of ProcessingTask or Curation
%         :param table: the class defining the table to retrieve
%          the loaded results from (e.g. ProcessingTask, Curation)
%         :return: a loader object of the loaded results
%          (e.g. suite2p.Suite2p, caiman.CaImAn, etc.)
%     """
%     method, output_dir = (ProcessingParamSet * table & key).fetch1(
%         'processing_method', _table_attribute_mapper[table.__name__])
% 
%     output_path = find_full_path(get_imaging_root_data_dir(), output_dir)
% 
%     if method == 'suite2p':
%         from element_interface import suite2p_loader
%         loaded_dataset = suite2p_loader.Suite2p(output_path)
%     elif method == 'caiman':
%         from element_interface import caiman_loader
%         loaded_dataset = caiman_loader.CaImAn(output_path)
%     else:
%         raise NotImplementedError('Unknown/unimplemented method: {}'.format(method))
% 
%     return method, loaded_dataset
end
