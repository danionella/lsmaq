function out = makeScanPattern(nSamplesPerLine, fillFraction, nLinesPerFrame, scanAmpXYZBP, offsetXYZBP, angleXYZ, bidir, zoom, piezoStepsN, phaseStepsN)
%MAKESCANPATTERNXY Generate mirror command signals for one frame
%   out = makeScanPattern(nSamplesPerLine, fillFraction, nLinesPerFrame, scanAmpXY, offsetXY, angle)
%   Generates an n-by-5 matrix of scan mirror command signals for one
%   frame using smooth, parabolic flybacks. The five columns correspond to
%   [X,Y,Z,blank,phase], which are X,Y,Z mirror / piezo command signals,
%   the Pockels cell blanking signal and a phase signal for phase stepping.
%
%   <nSamplesPerLine>:  number of output samples per line (including flyback)
%   <fillFraction>:     fill fraction (fillFraction * nSamplesPerLine has to be whole-numbered)
%   <nLinesPerFrame>:   number of lines per frame
%   <scanAmpXYZBP>:     1x2 to 1x5 vector of [X,Y,Z,blank,phase] scan amplitudes
%                       ([x,y] corresponds to [x,y,0,0,0])
%   <offsetXYZBP>:      1x2 to 1x5 vector of [X,Y,Z,blank,phase] scan offsets
%   <angleXYZ>:         scalar scan rotation angle in the XY plane (rotation around Z-axis)
%                       or 1x3 vector of angles (around X-, Y- and Z-axis). In degrees
%   <bidir>:            true/false flag for bidirectional scanning
%   <zoom>:             zoom factor applied to X and Y axis before rotation and offsets
%   <piezoStepsN>:      number of slices (piezo scanning). Default 1
%   <phaseStepsN>:      number of phases scanned. Default 1
%
%   example:
%       out = makeScanPattern(625, 0.8192, 32, [1 1 1], [0 0 0], [0 0 0], false, 2, 4);
%       figure, plot3(out(:, 1), out(:, 2), out(:, 3)), xlim([-1.1 1.1]), ylim([-1.1 1.1])
%
%   See also makeSawtooth, makeParabTrans
%
%   Revision history:
%   01.10.2018: added support for phase-stepping
%   18.06.2015: added support for piezo z-scanning, INP
%   23.07.2007: major updates for 3D scanning, BJ
%   05.04.2006: created, BJ

%process inputs
scanAmpXYZBP(end+1:5) = 0;
offsetXYZBP(end+1:5) = 0;
if numel(angleXYZ) == 1, angleXYZ = [0 0 angleXYZ]; end

%precalc
nFillSamples = ceil(nSamplesPerLine * fillFraction);
nFlybackSamples = nSamplesPerLine - nFillSamples;

%make the sawtooth for the X-scanner:
if bidir
    outX = repmat(  makeBidirectional(nSamplesPerLine, fillFraction)  , [nLinesPerFrame/2*piezoStepsN 1]);
else
    outX = repmat(  makeSawtooth(nFillSamples, nFlybackSamples)  , [nLinesPerFrame*piezoStepsN 1]);
end

outY = repmat(  makeSteps(nLinesPerFrame/phaseStepsN, nSamplesPerLine*phaseStepsN, nFlybackSamples)  , [piezoStepsN 1]);
outZ = makeSteps(piezoStepsN, nSamplesPerLine*nLinesPerFrame, nFlybackSamples);
outPhi = repmat(  makeSteps(phaseStepsN, nSamplesPerLine, nFlybackSamples)  , [nLinesPerFrame/phaseStepsN*piezoStepsN 1]);

%add blanking output (for Pockels signal)
blank = [ones(nFillSamples, 1); zeros(nFlybackSamples, 1)];
blank = repmat(blank, [nLinesPerFrame*piezoStepsN 1]);

%scale (apply zoom only to X and Y)
out = [outX outY outZ blank outPhi] .* (scanAmpXYZBP ./ [zoom zoom 1 1 1]);

%rotate
angleXYZ = pi*angleXYZ/180;
if any(angleXYZ ~= 0) %any(angleXYZ(1:2) ~= 0) %if doing z-scan
    rmZ = [cos(angleXYZ(3)) sin(angleXYZ(3)) 0; -sin(angleXYZ(3)) cos(angleXYZ(3)) 0; 0 0 1];
    rmY = [cos(angleXYZ(2)) 0 sin(angleXYZ(2)); 0 1 0; -sin(angleXYZ(2)) 0 cos(angleXYZ(2))];
    rmX = [1 0 0; 0 cos(angleXYZ(1)) sin(angleXYZ(1)); 0 -sin(angleXYZ(1)) cos(angleXYZ(1))];
    out(:, 1:3) = (rmZ * rmY * rmX * out(:, 1:3)')';
end

%add offsets
out = out + offsetXYZBP;



function out = makeSteps(nSteps, nSamplesPerLine, nFlybackSamples)
    YLevels = linspace(-1, 1, nSteps); if nSteps == 1, YLevels = 0; end
    nFillSamples = nSamplesPerLine - nFlybackSamples;
    out = repmat(YLevels, [nSamplesPerLine 1]);
    dV = diff([YLevels YLevels(1)]);
    flyback = makeParabTrans(nFlybackSamples)';
    out(nFillSamples+1:end, :) = flyback.*dV+YLevels;
    out = out(:);

function out = makeBidirectional(nSamples, fraction)

    f = (1-fraction)/2;
    x = 1:nSamples+1;
    x = x(1:end-1)/nSamples;
    indFraction = round(f*nSamples);
    bend = -1/(f*fraction)*(x(end-indFraction+1:end)-1).^2 + 1 + f/fraction;
    out = [2/fraction*(x(indFraction+1:end-indFraction))-1/fraction, bend, fliplr(bend) ];
    out = [out, -out]';

function trans = makeParabTrans(nSamples)
%MAKEPARABTRANS Generate a smoth parabolic transition
%   trans = makeParabTrans(nSamples) generates a smooth parabolic transition
%   (transition) for a mirror command voltage change from 0 to 1.
%   <nSamples> is the number of transition samples.
%
%   example for a transition between -1 and 2:
%       level1 = -1; level2 = 2;
%       trans = makeParabTrans(10)
%       trans = trans*(level2-level1)+level1;
%       plot([ones(1, 10)*level1 trans ones(1, 10)*level2], '.')
%
%   See also makeScanPatternXY, makeSawtooth
%
%   Revision history:
%   02.04.2006: created, BJ

x = linspace(0, 2, nSamples + 2);
trans(abs(x)<=1) = x(x<=1).^2 - 1; trans(abs(x)>1) = -(x(x>1)-2).^2 + 1;
trans = (-trans(2:end-1)/trans(1) + 1)/2;


function out = makeSawtooth(nFillSamples, nFlybackSamples)
%MAKESAWTOOTH Generate mirror command sawtooth
%   out = makeSawtooth(nFillSamples, nFlybackSamples) generates a
%   sawtooth with a linear up-slope and smooth parabolic flyback
%
%   See also makeScanPatternXY, makeParabTrans
%
%   Revision history:
%   08.10.2018: updated (now uses makeParabTrans), BJ
%   02.04.2006: created, BJ

start = (1/2)/(nFillSamples/nFlybackSamples); start = -start/(1+start); %this line computes at which x-position the slopes of both functions are equal
x = linspace(start, 2-start, nFlybackSamples+2);
%this implements the function y = {x^2-1 for x <=1; (x-2)^2+1 for x>1}:
flyback(x<=1) = x(x<=1).^2 - 1; flyback(x>1) = -(x(x>1)-2).^2 + 1;
flyback = flyback(2:end-1)/flyback(1);
out = [linspace(-1, 1, nFillSamples) flyback]';
