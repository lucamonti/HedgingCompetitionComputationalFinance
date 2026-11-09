function data = buildInternalData(raw)
%BUILDINTERNALDATA Turn the row-per-option columns of the dataset into the
% internal format described in loadData.m. Plain array code (no tables), so
% it runs in MATLAB and Octave.
%   raw: struct of column vectors, one entry per row of the dataset, with
%        fields date (datenum), code (yyyymm of the underlying futures),
%        isCall, strike, optBid, optAsk, optSettle, expiry (datenum),
%        futSettle, futBid, futAsk, sofrPct (percent)

% ---- remove duplicate quotes (e.g. a date present in two files) ----
[~, ia] = unique([raw.date(:), raw.code(:), double(raw.isCall(:)), raw.strike(:)], 'rows', 'last');
fn = fieldnames(raw);
for k = 1:numel(fn)
    raw.(fn{k}) = raw.(fn{k})(ia);
end

% ---- futures: one row per date, one column per contract ----
[dU, ~, iD] = unique(raw.date);
[cU, ~, iC] = unique(raw.code);
nD = numel(dU);
nC = numel(cU);
data.fut.dates  = dU(:);
data.fut.codes  = cU(:)';
data.fut.settle = pivot(iD, iC, raw.futSettle, nD, nC);
data.fut.bid    = pivot(iD, iC, raw.futBid,    nD, nC);
data.fut.ask    = pivot(iD, iC, raw.futAsk,    nD, nC);
% Futures settlements exist only on dates where the dataset has rows for the
% options on that contract: the Apr21 futures, for example, stop on 23 Feb 2021
% (expiry of the Apr21 options) although the futures trade until 26 Feb.

% ---- options ----
data.opt.date   = raw.date(:);
data.opt.code   = raw.code(:);
data.opt.isCall = logical(raw.isCall(:));
data.opt.strike = raw.strike(:);
data.opt.bid    = raw.optBid(:);
data.opt.ask    = raw.optAsk(:);
data.opt.settle = raw.optSettle(:);
data.opt.expiry = raw.expiry(:);

% ---- SOFR: one overnight rate per date ----
r = pivot(iD, ones(size(iD)), raw.sofrPct, nD, 1) / 100;
% SOFR is not published on US holidays: carry the previous value forward
firstOk = find(~isnan(r), 1);
r(1:firstOk-1) = r(firstOk);
for k = firstOk+1:nD
    if isnan(r(k))
        r(k) = r(k-1);
    end
end
data.sofr.dates = dU(:);
data.sofr.rate  = r;
end

function M = pivot(iRow, iCol, v, nR, nC)
% M(iRow, iCol) = v; NaNs never overwrite a number
M  = NaN(nR, nC);
ok = ~isnan(v);
M(sub2ind([nR nC], iRow(ok), iCol(ok))) = v(ok);
end
