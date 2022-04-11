function obj = getSchema
 persistent OBJ 
 if isempty(OBJ) 
     OBJ = dj.Schema(dj.conn,'ca', 'tacsPosner');
 end
 obj = OBJ;
 end 
