function p = normCdf(x)
%NORMCDF Standard normal cdf (no Statistics Toolbox needed).
p = 0.5 * erfc(-x / sqrt(2));
end
