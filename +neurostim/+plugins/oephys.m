classdef oephys < neurostim.plugins.ePhys
  % Plugin for interacting with the Open Ephys GUI v0.6.x via the REST API
  %
  % Version 0.6 of the open ephys GUI introduced a new REST API for remote
  % control and streaming. This plugin provides a wrapper for the REST API.
  % It is not compatible with versions of the open ephys GUI before v0.6.
  %
  % Note: if you are using a version of the open ephys GUI prior to 0.6.0-rc1
  %       you should look at plugins.openEphys.
  %
  % Example usage:
  %
  %   o = neurostim.plugins.oephys(c,'oephys');
  %   o.hostAddr = 'http://localhost:37497';
  %
  % Optional parameters may be specified via name-value pairs:
  %
  %   recordDir   - directory for saving data on the open ephys computer (default: '')
  %   prependText - prefix for recording directory names in recordDir (default: '')
  %   appendText  - suffix for recording directory names in recordDir (default: '')
  %
  %   signalChain - path to the open ephys signal chain .xml file on the
  %                 open ephys computer (default: '')
  %
  % See also: neurostim.plugins.ePhys
  
  % 2022-06-08 - Shaun L. Cloherty <s.cloherty@ieee.org>
  
  properties (Constant, Access = private)
    formats = {'BINARY'};
  end

  methods (Access = public)

    function o = oephys(c,name,varargin)

      % check whether urlread2() is on the search path
      url = 'https://mathworks.com/matlabcentral/fileexchange/35693-urlread2';
      assert(exist('urlread2','file') == 2, ...
        'Cannot find urlread2(). Please add it to your path:\n%s',url);
      
      % call parent class constructor
      o = o@neurostim.plugins.ePhys(c,name,varargin{:});

      % parse arguments
      p = inputParser;
      p.KeepUnmatched = true;
      p.addParameter('recordDir','',@ischar);
      p.addParameter('prependText','',@ischar);
      p.addParameter('appendText','',@ischar);

      p.addParameter('format','BINARY',@(x) ischar(x) && ismember(x,o.formats));

      p.addParameter('signalChain','',@ischar);

      p.parse(varargin{:});
      
      args = p.Results;
      %

      % add class properties
      o.addProperty('recordDir',args.recordDir,'validate',@ischar);
      o.addProperty('prependText',args.prependText,'validate',@ischar);
      o.addProperty('appendText',args.appendText,'validate',@ischar);

      o.addProperty('format',args.format,'validate',@(x) ischar(x) && ismember(x,o.formats));

      o.addProperty('signalChain',args.signalChain,'validate',@ischar);
    end
        
    function sendMessage(o,msg)
     % disp('attempting to contact oephys')
      % send a message to open ephys
      if ~iscell(msg)
        msg = {msg};
      end

      for ii = 1:numel(msg)
        o.put('message',struct('text',msg{ii}));
      end
    end

  end % public methods
    
  methods (Access = protected)
    function startRecording(o)
      % Start RECORDing

      if ~isempty(o.signalChain)
        o.put('load',o.signalChain);
      end

      % configure "global" recording information
      config = struct('prepend_state',2,'prepend_text',o.prependText,'append_text',o.appendText);
      r = o.put('recording',config);

      % FIXME: 2022-06-09
      %        do we need to specify parent_directory for each Record Node
      %        in the signal chain? In testing, the global settings are NOT
      %        inherited by the Record Nodes when recording starts.
      %
      %        Update: parent_directory is ignored if the directory does
      %        not exist on the open ephys computer...
      %
      %        2022-06-10
      %        parent_directory is only inherited by the Record Nodes when
      %        they are added to the signal chain... i.e., in the RecordNode
      %        constructor. wtf? what good is that?
      %
      %        to set the recording directory of each Record Node, PUT to
      %        `/api/recording/<processor_id>`
      %
      %        prepend_text and append_text are inherited by the Record Nodes
      %        when recording starts... at least, the Record Nodes honour
      %        the generated directory name, that includes prepend_text and
      %        append_text. 
      %
      %        It seems you cannot set the recording directory base name...
      %        that is always determined by the .xml file (either AUTO or
      %        CUSTOM)

%%%%%%%%%%%%
      % Set the parent directory on each active Record Node returned by the
      % Open Ephys REST API. The global /api/recording parent_directory does
      % not reliably update Record Nodes that are already present in the
      % signal chain; Open Ephys records to the per-node parent_directory.
      %
      % Previously this rig used a hard-coded endpoint:
      %   /api/recording/106
      % but Record Node IDs can change between signal chains/sessions. For
      % example, on 2026-06-29 the active Record Node was 101, so data saved
      % to D:\ instead of o.recordDir. This loop updates whatever Record
      % Node ID(s) the GUI reports at runtime.
      %
      % To reverse this change for a fixed-ID rig, comment out this loop and
      % restore a direct PUT to /api/recording/<node_id>.
      % This is Shaun's OG method too:
      
      %for nodeId = [r.record_nodes.node_id]
        %o.put({'recording',num2str(nodeId)},struct('parent_directory',o.recordDir));
      %end

      for nodeId = [r.record_nodes.node_id]
        o.put({'recording',num2str(nodeId)}, ...
          struct('parent_directory',o.recordDir, ...
                 'prepend_state',2, ...
                 'prepend_text',o.prependText, ...
                 'append_text',o.appendText));
      end

      % Old fixed-node workaround. Disabled because node_id 106 was not the
      % active Record Node on this rig.
      % out = webwrite('http://130.194.192.3:37497/api/recording/106', struct('parent_directory',o.recordDir), ...
      %     weboptions('RequestMethod','put','MediaType','application/json'));

      % This changes global recording settings only; it does not reliably
      % update existing Record Nodes.
      % out = webwrite([o.hostAddr, '/api/recording'], struct('base_text',o.recordDir), ...
      %       weboptions('RequestMethod','put','MediaType','application/json'));
%%%%%%%%%%%%

      [~,status] = o.put('status',struct('mode','RECORD')); %NP - this works

      % FIXME: check response to ensure 'mode' *is* 'RECORD'

      o.connectionStatus = status.status; % <-- FIXME: is this used/useful for anything?

      % TODO: 2022-06-09
      %       Can we get open ephys clock time via the REST API? If so,
      %       save it in o.clockTime for offline alignment...
    end

    function stopRecording(o)
      % Stop RECORDing

      [~,status] = o.put('status',struct('mode','IDLE'));

      o.connectionStatus = status.status;
    end

    function [response,status] = put(o,endpoint,payload)
      
      % issue http PUT request to the GUI
      %
      %   [response,status] = o.put(endpoint,payload)

      if ~iscell(endpoint)
        endpoint = {endpoint};
      end

      url = strjoin({o.hostAddr,'api',endpoint{:}},'/');

      json = jsonencode(payload);

      header = struct('name','Content-Type','value','application/json');

      % fprintf('Putting to %s ...', url);
      [response,status] = urlread2(url,'PUT',json,header); %, 'TIMEOUT', 5);
      if status.isGood
        fprintf('Put to oephys. \n')
      else
         keyboard;
      end

      assert(status.status.value == 200,'PUT request for %s returned %i:%s.', ...
        url,status.status.value,status.status.msg);

      response = jsondecode(response);
    end

    function [response,status] = get(o,endpoint)
      % issue http GET request to the GUI
      %
      %   [response,status] = o.get(endpoint,payload)

      if ~iscell(endpoint)
        endpoint = {endpoint};
      end

      url = strjoin({o.hostAddr,'api',endpoint{:}},'/');
      
      fprintf('Getting from %s ...', url);
       
      [response,status] = urlread2(url,'GET','TIMEOUT', 5);
      if status.isGood
        fprintf('Got. /n')
      else
         keyboard;
      end

      

      assert(status.status.value == 200,'GET request for %s returned %i:%s.', ...
        url,status.status.value,status.status.msg);

      response = jsondecode(response);
    end

  end % protected methods

end % classdef