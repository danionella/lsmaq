function [prop, configs] = defaultProps
%set default grab and scan properties

prop.grabcfg.dirName = 'C:\DATA';
prop.grabcfg.fileBaseName = [datestr(now,'yymmdd') '_n'];
prop.grabcfg.fileNumber = 1;                %current file number (will be appended to name)
prop.grabcfg.nFrames = 10;                  %number of frames to grab
prop.grabcfg.stackNumXyz = [1 1 50];        %number of stacks/tiles in X/Y/Z
prop.grabcfg.stackDeltaXyz = [0 0 5];       %stack and tile separation along X/Y/Z
prop.grabcfg.stackSequence = 'ZXY';         %stack scan sequence e.g. 'ZXY' to scan first along Z, then X, then Y
prop.grabcfg.powerDecayLength = Inf;        %power decay length in um

prop.scancfg.bidirectional = false;         %toggle bidirectional scaning
prop.scancfg.fillFraction = 800/1000;       %fraction of line not used for flyback
prop.scancfg.sampleLag = 94;               %galvo lag in AI samples
prop.scancfg.nInSamplesPerLine = 2000;      %input samples per line. this sets the line rate
prop.scancfg.nLinesPerFrame = 400;          %number of lines per frame
prop.scancfg.nPixelsPerLine = 400;          %number of Pixels per line
prop.scancfg.piezoStepsN = 1;               %number of evenly spaced piezo steps
prop.scancfg.phaseStepsN = 1;               %number of evenly spaced piezo steps
prop.scancfg.scanAmp = [1 -1 0 1 1];        %[X Y] amplitudes (optional: [X,Y,Z,blank,phase] amplitudes)
prop.scancfg.scanAngle = 0;                 %in-plane scan angle (optional: angles around [X,Y,Z] axes)
prop.scancfg.scanOffset = [0 0 0 0 0];      %[X Y] offsets (optional: [X,Y,Z,blank,phase] offsets)
prop.scancfg.zoom = 1;                      %zoom factor


% DEFAULT
temp = prop.scancfg;
configs.default_ = temp;

% b400x400_1ks
temp = []; %prop.scancfg;
temp.bidirectional = true;
temp.nInSamplesPerLine = 500;
temp.fillFraction = 800/1000;
temp.nLinesPerFrame = 400;
temp.nPixelsPerLine = 400;
configs.bi_400x400_500s = temp;

% b200x200_0.5ks
temp = []; %prop.scancfg
temp.bidirectional = true;
temp.nInSamplesPerLine = 500;
temp.fillFraction = 0.8;
temp.nLinesPerFrame = 200;
temp.nPixelsPerLine = 200;
configs.bi_200x200_500s = temp;

% u800x800_2ks
temp = []; %prop.scancfg
temp.bidirectional = false;
temp.nInSamplesPerLine = 2000;
temp.fillFraction = 800/1000;
temp.nLinesPerFrame = 800;
temp.nPixelsPerLine = 800;
configs.uni_800x800_2ks = temp;