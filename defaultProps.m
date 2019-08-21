function prop = defaultProps
%set default grab and scan properties

prop.grabcfg.dirName = 'C:\DATA';
prop.grabcfg.fileBaseName = [datestr(now,'yymmdd') '_n'];
prop.grabcfg.fileNumber = 1;                %current file number (will be appended to name)
prop.grabcfg.nFrames = 20;                  %number of frames to grab
prop.grabcfg.stackNumXyz = [1 1 50];        %number of stacks/tiles in X/Y/Z
prop.grabcfg.stackDeltaXyz = [0 0 5];       %stack and tile separation along X/Y/Z
prop.grabcfg.stackSequence = 'ZXY';         %stack scan sequence e.g. 'ZXY' to scan first along Z, then X, then Y

prop.scancfg.bidirectional = false;         %toggle bidirectional scaning
prop.scancfg.fillFraction = 800/1000;      %fraction of line not used for flyback
prop.scancfg.sampleLag = -25;
prop.scancfg.lineOffset = 0;
prop.scancfg.nInSamplesPerLine = 1000;      %input samples per line. this sets the line rate
prop.scancfg.nLinesPerFrame = 400;          %number of lines per frame
prop.scancfg.nPixelsPerLine = 400;          %number of Pixels per line
prop.scancfg.piezoStepsN = 1;               %number of evenly spaced piezo steps
prop.scancfg.phaseStepsN = 1;               %number of evenly spaced piezo steps
prop.scancfg.scanAmp = [1 -1 0 1 1];        %[X Y] amplitudes (optional: [X,Y,Z,blank,phase] amplitudes)
prop.scancfg.scanAngle = 0;                 %in-plane scan angle (optional: angles around [X,Y,Z] axes)
prop.scancfg.scanOffset = [0 0 0 0 0];      %[X Y] offsets (optional: [X,Y,Z,blank,phase] offsets)
prop.scancfg.zoom = 1;                      %zoom factor
