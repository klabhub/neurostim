classdef texture < neurostim.stimulus
  % Stimulus class to manage and present textures.
  %
  % Settable properties:
  %   width - width on screen (screen units)
  %   hight - height on screen (screen units)
  %
  % Public methods:
  %   add(id,img) - add img to the texture library with identifier id
  
  % 2016-09-24 - Shaun L. Cloherty <s.cloherty@ieee.org>
  
  properties (Access = private)
    % each entry in the texture library TEX contains a structure
    % with fields:
    %   id - a unique identifier (id)
    %   img - the image (L, LA, RGB or RGBA)
    %   ptr - the ptb texture pointer
    tex = {};
  end
        
  % dependent properties, calculated on the fly...
  properties (Dependent, SetAccess = private, GetAccess = public)
    texIds@cell; % list of all texture ids
    numTex@double; % the number of textures
  end
  
  methods % set/get dependent properties
    function value = get.texIds(o)
      value = cellfun(@(x) x.id,o.tex,'UniformOutput',false);
    end
    
    function value = get.numTex(o)
      value = length(o.tex);
    end
  end
  
  methods (Access = public)
    function o = texture(c,name)
      o = o@neurostim.stimulus(c,name);
      o.listenToEvent({'BEFOREFRAME','BEFOREEXPERIMENT','AFTEREXPERIMENT'});
            
      % add texture properties
      o.addProperty('id',[]); % id of the texture to show on the next frame
      o.addProperty('width',1.0,'validate',@isnumeric);
      o.addProperty('height',1.0,'validate',@isnumeric);
    end
        
    function o = add(o,id,img)
      % add IMG to the texture library, with texture id ID
      %
      % IMG can be a NxM matrix of pixel luminance values (0..255), an
      % NxMx3 matrix containing pixel RGB values (0..255) or an NxMx4
      % matrix containing pixel RGBA values. Alpha values range between
      % 0 (transparent) and 255 (opaque)
      
      % check if ID already exists
      idx = o.getIdx(id);
      if isempty(idx),
        % new texture
        idx = length(o.tex)+1;
      end
      
      assert(numel(idx) == 1,'Duplicate texture Id %s found!',id);

      o.tex{idx} = struct('id',id,'img',img,'ptr',[]);
      
      o.id = id; % last texture added is displayed next...?
    end

    function beforeExperiment(o,~,~)
      % create the ptb textures
      for ii = 1:o.numTex,
        o.tex{ii}.ptr = Screen('MakeTexture',o.cic.window,o.tex{ii}.img);
      end
    end
        
    function afterExperiment(o,~,~)
      % clean up the ptb textures
      ptr = cellfun(@(x) x.ptr,o.tex,'UniformOutput',true);
      Screen('Close',ptr);
    end
        
    function beforeFrame(o,~,~)
      % x.tex is the texture library
      if isempty(o.tex); return; end
      
      % get texture(s) to draw
      idx = o.getIdx(o.id);
      
      ptr = cellfun(@(x) x.ptr,o.tex(idx),'UniformOutput',true);

      rect = kron([-1,1],[o.width,-1*o.height]/2);    

      % draw the texture
      filterMode = 1; % bilinear interpolation
      Screen('DrawTextures',o.cic.window,ptr,[],rect',[],filterMode,o.alpha);
    end    
  end % public methods
    
  methods (Access = public)
    function idx = getIdx(o,id)
      % get index into tex of supplied id(s)
      if isempty(o.tex),
        idx = [];
        return;
      end

      if ~iscell(id),
        id = arrayfun(@(x) x,id,'UniformOutput',false);
      end
      
      idx = cellfun(@(x) find(cellfun(@(y) isequal(x,y),o.texIds)),id,'UniformOutput',false);
      idx = cell2mat(idx);
    end
  end % private methods
  
end % classdef
