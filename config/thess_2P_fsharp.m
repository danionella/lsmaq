function [prop, rigprops, scanconfigs] = thess_2P_fsharp % <- make sure to rename the function name to fit your file name

[prop, rigprops, scanconfigs] = defaultConfig;      % load defaultConfig and overwrite any parameters below

% RIG COFIGURATION
rigprops.AIrate = 1e6;                               % analog input sample rate in Hz
rigprops.AOrate = 250000;                             % analog output sample rate in Hz (has to be divisor of AIrate)
rigprops.AIrange = [-1 1];                           % analog input voltage range (2-element vector)
rigprops.AOchans = {'Dev1/ao0:1', 'Dev2/ao0:2'};   % cell array of AO channel paths. For a single AO card, this would be a 1-element cell, e.g. {'Dev1/ao0:1'}, for two cards, this could be {'Dev1/ao0:1', 'Dev2/ao0:2'}
rigprops.channelOrder = {[3 3], [1 2 5]};          % cell array of signal to channel assignments. Assign [X,Y,Z,Blank,Phase] signals (in that order, 1-based indexing) to output channels. To assign X to the first output channel, Y to the second, blank to the first of the second card and Z to the second of the second card, use {[1 2], [4 3]}. For a single output card, this could be e.g. {[1 2]}
%rigprops.channelScale = {[0 0], [1 1 1]};   
rigprops.pmtPolarity = 1;                            % invert PMT polarity, if needed (value: 1 or -1)
%rigprops.stageCreator = @() MP285('COM10', [10 10 25]);	% function that takes no arguments and returns a stage object (containing methods getPos and setPos, e.g. @() MP285('COM3', [10 10 25])) or empty
rigprops.powercontrolCreator = [];                   % function that takes no arguments and returns a powercontrol object (containing methods getPower and setPower)
rigprops.laserSyncPort = '';                         % leave empty if not syncing, sets SampleClock source of AI and TimeBaseSource of AO object, pulse rate is assumed to be AIRate

% DEFAULT (STARTUP) GRAB AND SCAN PROPERTIES
prop.grabcfg.dirName = 'C:\DATA';
prop.grabcfg.fileBaseName = [datestr(now,'yymmdd') '_n'];
prop.grabcfg.fileNumber = 1;                %current file number (will be appended to name)
prop.grabcfg.nFrames = 10;                  %number of frames to grab
prop.grabcfg.stackNumXyz = [1 1 50];        %number of stacks/tiles along X/Y/Z
prop.grabcfg.stackDeltaXyz = [0 0 5];       %stack and tile separation along X/Y/Z
prop.grabcfg.stackSequence = 'ZXY';         %stack scan sequence e.g. 'ZXY' to scan first along Z, then X, then Y
prop.grabcfg.powerDecayLength = Inf;        %power decay length in um
prop.scancfg.bidirectional = false;         %toggle bidirectional scaning
prop.scancfg.fillFraction = 800/1000;       %fill fraction (fraction samples not used for flyback)
prop.scancfg.sampleLag = 100;                %galvo lag in AI samples
prop.scancfg.nInSamplesPerLine = 2000;      %input samples per line. this sets the line rate
prop.scancfg.nLinesPerFrame = 400;          %number of lines per frame
prop.scancfg.nPixelsPerLine = 400;          %number of Pixels per line
prop.scancfg.scanAmp = [1 1 0 1 1];         %[X Y] amplitudes (optional: [X,Y,Z,blank,phase] amplitudes)
prop.scancfg.zoom = 1;                      %zoom factor

% ALTERNATIVE SCAN CONFIGURATIONS (can be selected from UI dropdown list)
scanconfigs.default_ = prop.scancfg;
scanconfigs.bi_400x400_500s = struct('bidirectional', true, 'nInSamplesPerLine', 500, ...
    'fillFraction',  0.8, 'nLinesPerFrame', 400, 'nPixelsPerLine', 400, 'scanAmp', [1 1 0 1 1]);
scanconfigs.bi_200x200_500s = struct('bidirectional', true, 'nInSamplesPerLine', 500, ...
    'fillFraction',  0.8, 'nLinesPerFrame', 200, 'nPixelsPerLine', 200, 'scanAmp', [1 1 0 1 1]);
scanconfigs.bi_200x100_500s_aniso = struct('bidirectional', true, 'nInSamplesPerLine', 500, ...
    'fillFraction',  0.8, 'nLinesPerFrame', 200, 'nPixelsPerLine', 100, 'scanAmp', [1 1 0 1 1]);
scanconfigs.bi_200x100_500s_iso = struct('bidirectional', true, 'nInSamplesPerLine', 500, ...
    'fillFraction',  0.8, 'nLinesPerFrame', 200, 'nPixelsPerLine', 100, 'scanAmp', [1 0.5 0 1 1]);
scanconfigs.uni_800x800_2ks = struct('bidirectional', true, 'nInSamplesPerLine', 2000, ...
    'fillFraction',  0.8, 'nLinesPerFrame', 800, 'nPixelsPerLine', 800, 'scanAmp', [1 1 0 1 1]);
