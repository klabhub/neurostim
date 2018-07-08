classdef texture < neurostim.stimulus
  % Stimulus class to manage and present textures.
  %
  % Settable properties:
  %   id      - id(s) of the texture(s) to show on
  %             the next frame
  %   width   - width on screen (screen units)
  %   height  - height on screen (screen units)
  %   xoffset - offset applied to X coordinate (default: 0)
  %   yoffset - offset applied to Y coordinate (default: 0)
  %
  % Public methods:
  %   add(id,img)     - add img to the texture library, with identifier id
  %   mkwin(sz,sigma) - calculate a gaussian transparency mask/window
  %
  % Multiple textures can be rendered simultaneously by setting
  % any or all of the settable properties to be a 1xN vector.

  % 2016-10-08 - Shaun L. Cloherty <s.cloherty@ieee.org>
  
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
            
      % add texture properties
      o.addProperty('id',[]); % id(s) of the texture(s) to show on the next frame

      o.addProperty('width',1.0,'validate',@isnumeric);
      o.addProperty('height',1.0,'validate',@isnumeric);
      
      o.addProperty('xoffset',0.0,'validate',@isnumeric);
      o.addProperty('yoffset',0.0,'validate',@isnumeric);
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

    function beforeExperiment(o)
      % create the ptb textures
      for ii = 1:o.numTex,
        o.tex{ii}.ptr = Screen('MakeTexture',o.window,o.tex{ii}.img);
      end
    end
        
    function afterExperiment(o)
      % clean up the ptb textures
      ptr = cellfun(@(x) x.ptr,o.tex,'UniformOutput',true);
      Screen('Close',ptr);
    end
        
    function beforeFrame(o)
      % x.tex is the texture library
      if isempty(o.tex); return; end
      
      % get texture(s) to draw
      idx = o.getIdx(o.id);
      
      ptr = cellfun(@(x) x.ptr,o.tex(idx),'UniformOutput',true);

      % expand singletons to handle multiple textures...
      n = max([length(o.id), ...
               length(o.width),length(o.height), ...
               length(o.xoffset),length(o.yoffset)]);
 
      width = o.width;
      if length(width) ~= 1 && length(width) ~= n,
        o.cic.error('STOPEXPERIMENT',sprintf('%s.width must be 1x1 or 1x%i',o.name,n));
      end
      width(1:n) = width;
      
      height = o.height;
      if length(height) ~= 1 && length(height) ~= n,
        o.cic.error('STOPEXPERIMENT',sprintf('%s.height must be 1x1 or 1x%i',o.name,n));
      end
      height(1:n) = height;
      
      xoffset = o.xoffset;
      if length(xoffset) ~= 1 && length(xoffset) ~= n,
        o.cic.error('STOPEXPERIMENT',sprintf('%s.xoffset must be 1x1 or 1x%i',o.name,n));
      end
      xoffset(1:n) = xoffset;
      
      yoffset = o.yoffset;
      if length(yoffset) ~= 1 && length(yoffset) ~= n,
        o.cic.qerror('STOPEXPERIMENT',sprintf('%s.yoffset must be 1x1 or 1x%i',o.name,n));
      end
      yoffset(1:n) = yoffset;
      
      rect = kron([1,1],[xoffset(:),yoffset(:)]);      
      rect = rect + kron([-1,1],[width(:),-1*height(:)]/2);    

      % draw the texture
      filterMode = 1; % bilinear interpolation
      Screen('DrawTextures',o.window,ptr,[],rect',[],filterMode);
    end    
  end % public methods
    
  methods (Access = protected)
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
  end % protected methods
  
  methods (Static)
    function w = mkwin(sz,sigma)
      % make gaussian window
      %
      %   sz    - size of the image in pixels ([hght,wdth])
      %   sigma - sigma of the gaussian as a proportion
      %           of sz
      assert(numel(sz) >= 1 || numel(sz) <= 2, ...
        'SZ must be a scalar or 1x2 vector');
      
      sz(1:2) = sz; % force 1x2 vector

      x = [0:sz(2)-1]/sz(2);
      y = [0:sz(1)-1]/sz(1);
      [x,y] = meshgrid(x-0.5,y-0.5);
          
      [~,r] = cart2pol(x,y);
     
      w = normpdf(r,0.0,sigma);
      
      % normalize, 0.0..1.0
      w = w - min(w(:));
      w = w./max(w(:));
    end
  end % static methods
end % classdef
