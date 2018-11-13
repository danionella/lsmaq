classdef matmap < handle
% MATMAP Object interface for memory maps of mat files
%
% OPEN: 
% mm = matmap(fn, dset) opens dataset dset in file fn as a memory map
% mm = matmap starts an open dialog to selct a file and dataset
%
% CREATE: 
% mm = matmap(filename, dsetname, sz, dtype, chunksz) creates a file and a
% memory map to that file, where fn is the file name, dset is the data set
% name, sz is a vector of sizes, dtype is the data type (e.g. 'single',
% 'double', 'complex single') and chunksz is the chunk size.
% 
% EXAMPLE: 
%
% mm = matmap('test.mat', '/data', [10 20 30 40], 'double', [10 20 1 1]); 
% mm(1:5,1:3,1,1) = ones(5, 3) * 50;
% mm(:,:,1,1)
%
% See also H5CREATE, H5READ, H5WRITE, MEMMAPFILE

% REVISION HISTORY:
% 110701: creted, BJ
% 120920: updated, BJ
    
    
    properties (SetAccess = private )
        fn
        dset
        dtype
        sz
    end
    
    properties (Dependent = true)
        info
    end
    
    methods
        function obj = matmap(fn, dset, sz, dtype, chunk, comp)
            if nargin < 1
                [fn pn] = uigetfile;
                fn = [pn, filesep, fn];
                info = h5info(fn);
                dsets = {info.Datasets.Name};
                [s,v] = listdlg('PromptString','Select a dataset:','SelectionMode','single','ListString',dsets);
                dset = ['/' dsets{s}];
            end
            if nargin > 2
                if nargin < 6
                    comp = 0;
                end
                if nargin < 5
                    chunk = sz;
                end
                if nargin < 4
                    dtype = 'double';
                end
                if ~exist(fn,'file')
                    matmap_temp = 'matmap_temp';
                    save(fn, 'matmap_temp', '-V7.3');
                    fid = H5F.open(fn,'H5F_ACC_RDWR','H5P_DEFAULT');
                    H5L.delete(fid, '/matmap_temp', 'H5P_DEFAULT');
                    H5F.close(fid);
                end
                chunk(end+1:numel(sz)) = 1;
                if strcmp(dtype, 'complex')
                    h5createcomplex(fn, dset, sz, chunk, comp, true);
                elseif strcmp(dtype, 'complex single')
                    h5createcomplex(fn, dset, sz, chunk, comp, false);
                else
                    h5create(fn, dset, sz, 'ChunkSize', chunk, 'Datatype', dtype, 'Deflate', comp);
                end
            end
            obj.fn = fn;
            obj.dset = dset;
            obj.dtype = obj.info.Datatype.Class;
            obj.sz = obj.info.Dataspace.Size;
            
            function h5createcomplex(fn, dset, sz, chunk, comp, doDouble)
                fid = H5F.open(fn,'H5F_ACC_RDWR','H5P_DEFAULT');
                space_id = H5S.create_simple(numel(sz), fliplr(sz), fliplr(sz));
                if doDouble
                    type_id = H5T.create('H5T_COMPOUND', 16);
                    H5T.insert( type_id, 'real', 0, 'H5T_NATIVE_DOUBLE');
                    H5T.insert( type_id, 'imag', 8, 'H5T_NATIVE_DOUBLE');
                else
                    type_id = H5T.create('H5T_COMPOUND', 8);
                    H5T.insert( type_id, 'real', 0, 'H5T_NATIVE_FLOAT');
                    H5T.insert( type_id, 'imag', 4, 'H5T_NATIVE_FLOAT');
                end
                dcpl = H5P.create('H5P_DATASET_CREATE');
                H5P.set_chunk(dcpl,fliplr(chunk));
                H5P.set_deflate(dcpl,comp);
                dset_id = H5D.create(fid,dset,type_id,space_id,'H5P_DEFAULT');
                H5S.close(space_id); H5T.close(type_id); H5P.close(dcpl); H5D.close(dset_id); H5F.close(fid);
            end
        end

        function out = alldata(obj)
            out = h5read(obj.fn, obj.dset);
            if strcmp(obj.dtype, 'H5T_COMPOUND')
                out = out.real + 1i * out.imag;
            end
        end
        
        function var = size(obj, k)
            var = obj.sz;
            if  nargin == 2
                var = var(k);
            end
        end
        
        function var = get.info(obj)
            var = h5info(obj.fn, obj.dset);
        end
        
        function varargout = subsref(obj, S)
            switch S(1).type
                case {'.'}
                    [varargout{1:nargout}] = builtin('subsref',obj,S);
                case '()'
                    [start, count] = obj.sub2startCount(S);
                    varargout{1} = h5read(obj.fn, obj.dset, start, count);
                    if strcmp(obj.dtype, 'H5T_COMPOUND')
                        varargout{1} = varargout{1}.real + 1i * varargout{1}.imag;
                    end
            end
        end
        
        function obj = subsasgn(obj, S, in)
            %if ~isreal(in), error('Doesn''t yet work for complex data!'), end
            [start, count] = obj.sub2startCount(S);
            if strcmp(obj.dtype, 'H5T_COMPOUND')
                h5writeComplex(obj.fn, obj.dset, in, start, count);
            else
                h5write(obj.fn, obj.dset, in, start, count);
            end
        end
        
        function ind = end(obj,k,~)
            sz = obj.size;
            ind = sz(k);
        end
        
        function [start, count] = sub2startCount(obj, S)
            sz = obj.size;
            dims = length(sz);
            start = ones(1, dims);
            count = start;
            nSubs = length(S(1).subs);
            
            for iSub = 1:length(S(1).subs)
                sub = S(1).subs{iSub};
                if ischar(sub) && strcmp(sub, ':')
                    start(iSub) = 1;
                    count(iSub) = sz(iSub);
                elseif isnumeric(sub)
                    if any(diff(sub) ~= 1), error('subs have to be contiguous!'), end
                    start(iSub) = sub(1);
                    count(iSub) = sub(end) - start(iSub) + 1;
                else
                    disp(sub), error('wrong subscript provided!')
                end
            end
            if nSubs < dims
                lastSub = S(1).subs{nSubs};
                if ischar(lastSub) && strcmp(lastSub, ':')
                    count(nSubs:dims) = Inf;
                elseif isnumeric(lastSub)
                    if numel(lastSub) ~= 1
                        error(['If less than ', num2str(dims), ' dimensions are specified, the last subscript has to be scalar!'])
                    end
                    if lastSub > prod(sz(nSubs:end))
                        error('Index exceeds matrix dimensions!')
                    end
                    sub = zeros(1, 10);
                    [sub(1) sub(2) sub(3) sub(4) sub(5) sub(6) sub(7) sub(8) sub(9) sub(10)] = ind2sub(sz(nSubs:end), lastSub);
                    start(nSubs:dims) = sub(1:dims-nSubs+1);
                end
                %error(['All ' num2str(dims) ' subscript dimensions needed!'])
            end
            %start, count
        end
        
    end %methods

end %classdef

