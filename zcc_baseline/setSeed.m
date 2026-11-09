function setSeed(seed)
%SETSEED Seed the random number generator (MATLAB and Octave).
if exist('rng') > 0 %#ok<EXIST>
    rng(seed);
else
    randn('state', seed); %#ok<RAND>
    rand('state', seed);  %#ok<RAND>
end
end
