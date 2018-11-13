classdef dynamicshell < dynamicprops
    %DYNAMICSHELL empty object dynamically added properties
    %
    %   See also ADDPROP, ADDLISTENER, DYNAMICPROPS
    
    properties
        
    end
    
    
    methods
        
        function obj = dynamicshell(s)
            if nargin >= 1
                for iFldn = fieldnames(s)'
                    p = addprop(obj, iFldn{1});
                    p.SetObservable = true;
                    p.GetObservable = true;
                    p.AbortSet = true;
                    if isstruct(s.(iFldn{1}))
                        obj.(iFldn{1}) = dynamicshell(s.(iFldn{1}));
                    else
                        obj.(iFldn{1}) = s.(iFldn{1});
                    end
                end %for
                
            end %if
        end
        
        function addHiddenProp(obj, s)
            if nargin >= 2
                for iFldn = fieldnames(s)'
                    p = addprop(obj, iFldn{1});
                    p.Hidden = true;
                    obj.(iFldn{1}) = s.(iFldn{1});
                end %for
                
            end %if
        end
        
        function appendStruct2Prop(obj, s)
            if nargin >= 2
                for iFldn = fieldnames(s)'
                    p = addprop(obj, iFldn{1});
                    p.SetObservable = true;
                    p.GetObservable = true;
                    p.AbortSet = true;
                    if isstruct(s.(iFldn{1}))
                        obj.(iFldn{1}) = dynamicshell(s.(iFldn{1}));
                    else
                        obj.(iFldn{1}) = s.(iFldn{1});
                    end
                end %for
            end
        end
        
        
        function s = tostruct(obj)
            for iFldn = (fieldnames(obj))'
                if isa(obj.(iFldn{1}), 'dynamicshell')
                    var = obj.(iFldn{1}).tostruct();
                else
                    var = obj.(iFldn{1});
                end
                s.(iFldn{1}) = var;
            end
        end
        
        
        function fn = properties(obj)
            fn = sort(builtin('properties', obj));
        end
        
        function fn = fieldnames(obj)
            fn = properties(obj);
        end
        
        function out = struct(obj)
            out = orderfields(builtin('struct', obj));
        end
        
        function [pp, pt, ptm, ppc] = inspect(varargin)
            [pp, pt, ptm, ppc] = propertytable(varargin{:});
            if nargin < 2, set(gcf, 'Name', inputname(1)), end
        end
        
    end %methods
    
end %classdef
