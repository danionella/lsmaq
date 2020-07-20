function hOverlay = overlayfigure(hIm)
%OVERLAYFIGURE creates an RGB overlay of existing images, which updates when source images change.
% 
%  hIm:     Array of source Image handles (max 3), to be assigned to the
%           red, green and blue channel.
%
%  Example:
%           figure, hIm(1) = imagesc(rand(100)); colormap gray
%           figure, hIm(2) = imagesc(rand(100)); colormap gray
%           overlayfigure(hIm);
%           hIm(1).CData = rand(100);

hF = figure('name', 'Overlay', 'menubar', 'none', 'toolbar', 'none', 'DoubleBuffer', 'off', 'visible', 'off');
hF.Position(3:4) = [512, 512]; 
movegui

hOverlay = imagesc(zeros([size(hIm(1).CData) 3])); 
axis square tight
set(gca, 'units', 'normalized', 'Position', [0 0 1 1]);
set(hF, 'visible', 'on')
hListener = addlistener(hIm,'CData','PostSet',@(varargin) test_fcn(hIm, hOverlay));
hF.CloseRequestFcn = @(hObj, ev) closeRequest(hObj, hListener);
test_fcn(hIm, hOverlay);

function test_fcn(hIm, hOverlay)
    for i = 1:numel(hIm)
        cl = hIm(i).Parent.CLim;
        chan = (hIm(i).CData - cl(1)) / (cl(2)-cl(1));
        chan(chan<0) = 0;
        chan(chan>1) = 1;
        hOverlay.CData(:,:,i) = chan;
    end
    
    
function closeRequest(hObject,hListener)
    delete(hListener)
    delete(hObject)