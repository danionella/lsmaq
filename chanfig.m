function [hIm, hF] = chanfig(chan)
%CHANFIG Opens channel figure for lsmaq

name = ['channel ', num2str(chan)];

%replace existing figure if necessary:
hF = findobj(0, 'type', 'figure', '-and', 'name', name);
if isempty(hF)
    hF = figure('name', name, 'NumberTitle', 'off', 'Tag', 'chanfig', ...
        'DoubleBuffer', 'off', 'visible', 'off');
else
    clf(hF)
end

%set figure, axis and image properties:
figure(hF);
pos = get(hF, 'Position'); set(hF, 'Position', [pos(1:2) 512 512]);
set(hF, 'menubar', 'none', 'toolbar', 'none', 'DoubleBuffer', 'off');
set(gca, 'units', 'normalized', 'Position', [0 0 1 1]);
axis square tight

% hIm = imagesc(0, [0 2^16-1]/2); colormap(gray); %caxis([0 10]);
hIm = imagesc(0, [0 1]); colormap(gray); %caxis([0 10]);


%ca = caxis;
ca = [0, 2^12];
caxis(ca)

uicontrol('String', mat2str(ca), 'Fontsize', 10, 'Units', 'normalized',...
    'Style','edit', 'BackgroundColor',[1 1 1], 'HorizontalAlignment', 'center',...
    'Callback',@setImageMax);

movegui
set(hF, 'visible', 'on')

function setImageMax(hObj, ~)
if ~isnan(eval(get(hObj, 'String')))
    caxis(eval(get(hObj, 'String')));
end