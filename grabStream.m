function [data, scannerOut] = grabStream(rig, prop, hIm, fStatus, fStripe)
%GRABSTREAM Grab images and display data online
%   data = grabStream(rig, scancfg, grabcfg, hIm);
%   Scans and records images according to parameters specified
%       <rig>       rig control structure as generated by rigStartup
%       <scancfg>   scan configuration structure
%       <grabcfg>   grab configuration structure
%       <hIm>       Handle of an image for online data display. EraseMode
%                   should be 'none'.
%       <fStatus>   (optional) Function handle of status function
%                   which is called by grabStream to e.g. update status
%                   text information. Arguments: fStatus(percent, text).
%       <fStripe>   (optional) Handle of a fucntion that is being called
%                   after each stripe has been acquired and displayed on
%                   screen. Arguments: fStripe(cdata, yIndices).
%
%   grabStream(rig, scancfg, grabcfg, hIm, fStatus);
%   If the function is called without output argument it uses less memory
%   since data doesn't have to be stored. Can be used for "focus" mode,
%   when no data is acquired.
%
%   See also raw2pixeldata, makeScanPatternXYZ
%
%   Revision history:
%   01.11.2018: moved all hard-coded DAQ functions to rigClass (and upgraded to .NET interface)
%   18.06.2015: extensive modification to work with session based DAQ, added z-scanning, INP
%   29.01.2009: added output of scannerOut to variable svxyz, SS
%   13.11.2007: added fStripe functionality, BJ
%   28.04.2006: created, BJ

scancfg = prop.scancfg;
grabcfg = prop.grabcfg;

% process inputs and outputs
isGrabbing = (nargout > 0);
if nargin < 4, fStatus = @(varargin) NaN; end

% Check input arguments
checkCfg();

% set lines per display stripe (smallest divisor of nLinesPerFrame >= 10)
nLinesPerStripe=find((rem(scancfg.nLinesPerFrame, 1:scancfg.nLinesPerFrame) == 0) & ((1:scancfg.nLinesPerFrame) >= 40), 1);

% initialize
iAcquiredLines = 0;
outdata = zeros(scancfg.nPixelsPerLine, scancfg.nLinesPerFrame, rig.AItask.AIChannels.Count, 'int16');
data = zeros([scancfg.nPixelsPerLine scancfg.nLinesPerFrame rig.AItask.AIChannels.Count grabcfg.nFrames*scancfg.piezoStepsN], 'int16');

% AI acquisition is continuous and will be stopped after all the expected data are collected
rig.setupAIlistener(@samplesAcquiredFun, nLinesPerStripe * scancfg.nInSamplesPerLine)

% AO
nOutSamplesPerLine = (rig.AOrate / rig.AIrate) * scancfg.nInSamplesPerLine;
scannerOut =  makeScanPattern(nOutSamplesPerLine, scancfg.fillFraction, scancfg.nLinesPerFrame, scancfg.scanAmp, scancfg.scanOffset, ...
        scancfg.scanAngle, scancfg.bidirectional, scancfg.zoom, scancfg.piezoStepsN, scancfg.phaseStepsN);
scannerOut(:,1:2) = circshift(scannerOut(:,1:2), round(-(rig.AOrate / rig.AIrate) * scancfg.sampleLag));
rig.queueOutputData(scannerOut); %queueOutputData(rig.aoSession, repmat(scannerOut(:, 1:3), [grabcfg.nFrames 1]));

%     figure(45), plot3(scannerOut(:, 1), scannerOut(:, 2), scannerOut(:, 5)), xlim([-1.1 1.1]), ylim([-1.1 1.1])
%     figure(46), plot(scannerOut)

% display
cax = (get(hIm, 'Parent')); if numel(cax) == 1, cax = {cax}; end
set([cax{:}], 'XLim', [0 scancfg.nPixelsPerLine], 'YLim', [0 scancfg.nLinesPerFrame])
set(hIm, 'XData', [1 scancfg.nPixelsPerLine]-0.5);
set(hIm, 'YData', [1 scancfg.nLinesPerFrame]-0.5);

fps = rig.AIrate / (scancfg.nLinesPerFrame * scancfg.nInSamplesPerLine);

%% START
% restartDio(rig);
t = tic;
rig.start();

rig.shutterOpen()
rig.hwTrigger()
rig.isScanning = true;

% cleanup if interrupted
cleanupObj = onCleanup(@(varargin) rig.stopAndCleanup);

try
    %WAIT until done
    if isGrabbing
        waitfor(rig, 'isScanning', false)
    else
        fStatus(NaN, ['live view @ ', num2str(fps, 3), ' fps ...']);
        waitfor(rig, 'isScanning', false)
    end
catch
    warning(lasterr)
end

rig.stopAndCleanup
rig.isScanning = false;
% delete(rig.ailh);


    % NESTED FUNCTIONS
    function samplesAcquiredFun(raw)
        nCurrentFrame = floor(iAcquiredLines / scancfg.nLinesPerFrame) + 1;
        if ~rig.isScanning || (isGrabbing && (nCurrentFrame > grabcfg.nFrames*scancfg.piezoStepsN)) , rig.isScanning = false; pause(0), return, end

        %%GET RAW DATA , SHAPE INTO IMAGE
        %raw = event.Data;
        yIndices = mod(iAcquiredLines, scancfg.nLinesPerFrame) + (1:nLinesPerStripe);
        outdata(:, yIndices ,:, :) = raw2pixeldata(raw', scancfg.nInSamplesPerLine, scancfg.fillFraction, 0, scancfg.nPixelsPerLine, scancfg.bidirectional);
        iAcquiredLines = iAcquiredLines + nLinesPerStripe;

        if isGrabbing
            %%copY SINGLE FRAME BUFFER INTO LARGE MULTIFRAME OUTPUT  MATRIX
            data(:, yIndices, :, nCurrentFrame) = outdata(:, yIndices, :);
            percent = (iAcquiredLines / scancfg.nLinesPerFrame) / double(grabcfg.nFrames);
            if toc(t) >= 0.2 %refreshing too often will overload the system
                fStatus(percent, ['acquiring @ ', num2str(fps, 2), ' fps ...']);
                t = tic;
            end
        end
        %% update CHANNEL FIGURE WITH LAST IMAGE
        for iChan = 1:length(hIm)
            set(hIm(iChan), 'XData', [1 scancfg.nPixelsPerLine]-0.5);
            set(hIm(iChan), 'YData', [1 scancfg.nLinesPerFrame]-0.5);
            set(hIm(iChan), 'CData', mean(outdata(:,:,iChan,:),4)');
        end

        if nargin >=6, fStripe(outdata, yIndices); end
        pause(0) %makes this callback interruptable (to stop acquisition)
    end

    function checkCfg()
        maxGalvoFreq = 1000;
        minInSamplesPerLine = rig.AIrate/maxGalvoFreq/(1+scancfg.bidirectional);
        if scancfg.nInSamplesPerLine < minInSamplesPerLine
            %scancfg.nInSamplesPerLine = minInSamplesPerLine;
            %warning(['Number of samples cannot be smaller than ' num2str(minInSamplesPerLine) '. Set automatically to ' num2str(minInSamplesPerLine) '.']);
            warning(['Number of samples cannot be smaller than  ' num2str(minInSamplesPerLine) ])
        end
        %scancfg.fillFraction = floor(scancfg.fillFractionMax*scancfg.nInSamplesPerLine/scancfg.nPixelsPerLine)*scancfg.nPixelsPerLine/scancfg.nInSamplesPerLine;
    end

end
