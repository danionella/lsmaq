function out = raw2pixeldata(rawdata, nSamplesPerLine, fillFraction, fillLag, nPixelsPerLine, bidir)
%RAW2PIXELDATA Converts raw samples from the DAQ card into images. Called
%   by grabStream/samplesAcquiredFun for each image stripe.

%precalc
nFillSamplesPerLine = nSamplesPerLine * fillFraction;
nSamplesPerPixel = 	(nFillSamplesPerLine / nPixelsPerLine);
startFillOdd = floor(fillLag*(nSamplesPerLine - nFillSamplesPerLine -1));
startFillEven = floor(fillLag*(nSamplesPerLine - nFillSamplesPerLine -1));

%cropping data (we only need fill fraction of data)
s = size(rawdata); % s(1)=number of samples in stripe; s(2)=number of channels
rawdata = reshape(rawdata, [round(nSamplesPerLine), s(1)/round(nSamplesPerLine) s(2)]);

if bidir
    temp = rawdata((1:nFillSamplesPerLine)+startFillOdd, :, :, :);
    temp(:, 2:2:end, :, :) = flip(rawdata((1:nFillSamplesPerLine)+startFillEven, 2:2:end, :, :), 1);
    rawdata = temp;
else
    rawdata = rawdata((1:nFillSamplesPerLine)+startFillOdd, :, :, :);
end

%reshaping data for binning
s = size(rawdata);
s(end+1:4)=1;
rawdata = reshape(rawdata, [round(nSamplesPerPixel) s(1)/nSamplesPerPixel s(2) s(3) s(4)]);
rawdata = mean(rawdata, 1);
out = shiftdim(rawdata, 1);
