function  [rig, prop, hIm] = lsmaq
%LSMAQ Starts the lsmaq UI and acquisition engine

%create and configure figure
if ~isempty(findobj(0, 'type', 'figure', 'tag', 'lsmaq'))
    error('please close existing lsmaq figures and try again')
end

% add prop folder to path
addpath([fileparts(mfilename('fullpath')) filesep 'prop'])

%get scan, grab and hardware configuration
prop = dynamicshell(defaultProps);

% Hardware configurations are added as hidden dynamic properties so that they don't overpopulate the GUI
%prop.addHiddenProp(loadjson([fileparts(mfilename('fullpath')) filesep 'configs' filesep 'hdwConfig.json']))

% Property window
hF = figure;
set(hF, 'NumberTitle', 'off', 'Name', 'lsmaq', 'CloseRequestFcn', @CloseRequestFcn, 'Tag', 'lsmaq',...
    'ToolBar', 'none', 'MenuBar', 'none', 'resize', 'off', 'DockControls', 'off', 'Position', [0 250 220 485])
hTb = makeToolBar(hF);
movegui(hF, [5+1, -5]); drawnow

%property inspector (main gui)
[pph, pt, ptmh, ppc] = prop.inspect(hF);
pth = handle(pt);
set(ppc, 'units', 'pixels', 'Position', [1 1 220 485-21])
setCustomCellEditor(ptmh, 'grabcfg.dirName', @(dp, button) dp.setValue(['''', uigetdir, '''']));

%status bar
statusBar = [];
updateStatus(NaN, 'starting up...')

%starting rig
rig = rigClass(@updateStatus);

%create channel figures
for i=1:double(rig.AItask.AIChannels.Count)
    [hIm(i), hChanF(i)] = chanfig(i); movegui([220+15+(i-1)*(512+10), -5])
end
set([hF hChanF], 'WindowScrollWheelFcn', @mouseWheelCb)

%initialize some global variables to be used by sub-functions
restartFocus = false;
isAcquiring = false;

%we are done
updateStatus(0, 'ready to go!')


% Creates toolbar and populates it with icons
    function hTb = makeToolBar(hF)
        hTb.Tb = uitoolbar(hF);
        icons = load('lsmaq_icons'); icons = icons.icons;
        hTb.Focus = uitoggletool(hTb.Tb, 'CData', icons.focus, 'TooltipString', 'Focus', 'onCallback', @startFocus, 'offCallback', @stopScanning);
        hTb.Grab = uitoggletool(hTb.Tb, 'CData', icons.grab, 'TooltipString', 'Grab', 'onCallback', @startGrab, 'offCallback', @stopScanning);
        hTb.Stop = uipushtool(hTb.Tb, 'CData', icons.stop, 'TooltipString', 'Stop', 'ClickedCallback', @stopScanning);
        hTb.Zstack = uitoggletool(hTb.Tb, 'CData', icons.stacks_blue, 'Separator', 'on', 'TooltipString', 'Acquire Stack', 'ClickedCallback', @startZStack, 'offCallback', @stopScanning, 'enable', 'on');
    end

% Starts the free-running focusing
    function startFocus(hObj, ignore)
        warning('off', 'daq:Session:tooFrequent')
        stopEditing
        updateStatus(NaN, 'focussing...');
        set([hTb.Grab hTb.Zstack], 'enable', 'off')
        restartFocus = false;
        channelAspRatio(hIm, rig, prop)
        try
            grabStream(rig, prop, hIm, @updateStatus);
        catch
            warning(lasterr)
        end
        set([hTb.Grab hTb.Focus], 'enable', 'on', 'state', 'off');
        if ~isempty(rig.stage.hPort) set(hTb.Zstack, 'enable', 'on', 'state', 'off'); end
        if restartFocus, restartFocus = false; pause(0.1), set(hTb.Focus, 'state', 'on'); end
        updateStatus(0, 'ready to go!');
        pth.Enabled = true;
    end

% Starts grabbing
    function startGrab(hObj, ignore)
        fn = sprintf('%s%s%s%04.0f.mat', prop.grabcfg.dirName, filesep, prop.grabcfg.fileBaseName, prop.grabcfg.fileNumber);
        if exist(fn, 'file'), warndlg('file exists'), return, end
        stopEditing
        isAcquiring = true;
        set([hTb.Focus hTb.Zstack], 'enable', 'off')
        channelAspRatio(hIm, rig, prop)
        data = grabStream(rig, prop, hIm, @updateStatus);
        config = prop.tostruct;
        save(fn, 'data', 'config', '-v7.3');
        fprintf('Saved to file %s \n', fn);
        set([hTb.Grab hTb.Focus], 'enable', 'on', 'state', 'off');
        if ~isempty(rig.stage.hPort) set(hTb.Zstack, 'enable', 'on', 'state', 'off'); end
        prop.grabcfg.fileNumber = prop.grabcfg.fileNumber + 1;
        updateStatus(0, 'ready to go!')
        pth.Enabled = true;
    end

    function startZStack(hObj, ignore)
        fn = sprintf('%s%s%s%04.0f.mat', prop.grabcfg.dirName, filesep, prop.grabcfg.fileBaseName, prop.grabcfg.fileNumber);
        if exist(fn, 'file'), warndlg('file exists'), return, end
        stopEditing
        set(hTb.Focus, 'enable', 'off')
        updateStatus(NaN, 'Acquiring z-stack...')
        coords = getCoords(prop.grabcfg.stackNumXyz, prop.grabcfg.stackDeltaXyz, prop.grabcfg.stackSequence);
        nSlices = prod(prop.grabcfg.stackNumXyz);
        startPos = rig.stage.getPos;
        for iSlice = 1:nSlices
            if ~strcmp(get(hTb.Zstack, 'state'), 'on'), continue, end
            updateStatus(iSlice/nSlices, sprintf('Acquiring slice %d of %d (%s)', iSlice, nSlices, mat2str(coords(iSlice, :))) )
            rig.stage.moveAbs(coords(iSlice, :) + startPos);
            pause(0.2);
            data = grabStream(rig, prop, hIm, @updateStatus);
            if iSlice == 1
                sz = size(data); sz(end+1:4) = 1; sz(5) = nSlices;
                mm = matmap(fn, '/data', sz, 'int16', [sz(1:2)]);
            end
            mm(:,:,:,:,iSlice) = data;
        end
        rig.stage.moveAbs(startPos)
        config = prop.tostruct;
        save(fn, 'config', '-append')
        fprintf('Saved to file %s \n', fn);
        set([hTb.Grab hTb.Focus hTb.Zstack], 'enable', 'on', 'state', 'off');
        prop.grabcfg.fileNumber = prop.grabcfg.fileNumber + 1;
        updateStatus(0, 'ready to go!')
        pth.Enabled = true;

        function coords = getCoords(nXYZ, dXYZ, stackSequence)
            order = (stackSequence=='X') +  2*(stackSequence=='Y') + 3*(stackSequence=='Z'); %turn sttring into numeric stack order
            [nd(:,:,:,1), nd(:,:,:,2), nd(:,:,:,3)] = ndgrid((0:nXYZ(1)-1)*dXYZ(1), (0:nXYZ(2)-1)*dXYZ(2), (0:nXYZ(3)-1)*dXYZ(3));
            nd = permute(nd, [order 4]);
            coords = reshape(nd, [], 3);
        end
    end

    function stopScanning(~, ~)
        rig.shutterClose();
        rig.isScanning = false;
        %uiresume(hChanF(1))
    end

    function CloseRequestFcn(hF, ~)
        try close(hChanF), rig.shutterClose, end
        %       rig.stopAndCleanup(1);
        delete(hF)
        delete(rig.stage)
        daqreset
    end

    function mouseWheelCb(hObj, event)
        %changes zoom
        if isAcquiring, return, end
        scrollCount = -event.VerticalScrollCount;
        newzoom = 2^(round(scrollCount + log(prop.scancfg.zoom)/log(2^(1/4)))/4);
        newzoom = max([newzoom 1]);
        prop.scancfg.zoom = eval(mat2str(newzoom, 3));
        restartFocus = true;
        stopScanning();
        %uiresume(hChanF(1))
    end

    function stopEditing
        if ~isempty (pth.getCellEditor)
            pth.getCellEditor.stopCellEditing
        end
        pth.Enabled = false;
        drawnow
    end

    function updateStatus(percent, text)
        % I think this part sometimes causes errors
        if isempty(statusBar)
            [statusBar, ~] = javacomponent(javax.swing.JProgressBar, [1 1+485-20 220 20]);
            statusBar.StringPainted = true;
            statusBar.BorderPainted = false;
        end
        if isnan(percent)
            set(statusBar, 'Indeterminate', true)
        else
            set(statusBar, 'Indeterminate', false)
            set(statusBar, 'Value', percent * 100)
        end
        if nargin == 2
            set(statusBar, 'String', text)
        end
        drawnow
    end

    function channelAspRatio(hIm, rig, prop)
        for j = 1:rig.AItask.AIChannels.Count
            try
                hIm(j).Parent.DataAspectRatio = [prop.scancfg.nPixelsPerLine/prop.scancfg.nLinesPerFrame*abs(prop.scancfg.scanAmpXYZ(2)/prop.scancfg.scanAmpXYZ(1)) 1 1];
            catch
            end
        end
    end
end
