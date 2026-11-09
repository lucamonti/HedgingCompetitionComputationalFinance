function data = loadData(cfg)
%LOADDATA Read the parquet dataset(s) and convert them to the internal format.
%
% The dataset is one long table, one row per (date, option, strike, type),
% with the underlying futures and the SOFR rate repeated on every row.
% Columns used:
%   date, future_contract_code (e.g. 'COJ21' = Apr21), option_type ('Call'/'Put'),
%   strike, option_bid, option_ask, settlement_price, expiration,
%   underlying_settlement, underlying_bid, underlying_ask, sofr_rate (percent)
% Not used: settlement_vol (empty in the training file), atm_strike,
%   moneyness_usd, time_to_expiry_days, tickers (redundant).
%
% Internal format (built by buildInternalData.m)
%   data.fut.dates     T x 1  datenum, ascending
%   data.fut.codes     1 x C  contract month yyyymm (202104 = Apr21)
%   data.fut.settle    T x C  settlement prices, NaN when not in the data
%   data.fut.bid/ask   T x C  futures bid/ask, NaN when not in the data
%   data.opt.date/code/isCall/strike/bid/ask/settle/expiry   Q x 1 each
%   data.sofr.dates    D x 1  datenum
%   data.sofr.rate     D x 1  overnight SOFR, decimal, ACT/360
%
% parquetread needs MATLAB R2019a or later.

raw = struct('date', [], 'code', [], 'isCall', [], 'strike', [], 'optBid', [], ...
             'optAsk', [], 'optSettle', [], 'expiry', [], 'futSettle', [], ...
             'futBid', [], 'futAsk', [], 'sofrPct', []);

for f = 1:numel(cfg.dataFiles)
    fname = fullfile(cfg.dataDir, cfg.dataFiles{f});
    if ~isfile(fname)
        error('Data file not found: %s', fname);
    end
    T = parquetread(fname);

    % contract month of the underlying futures, 'COJ21' -> 202104
    [uName, ~, ic] = unique(string(T.future_contract_code));
    uCode = arrayfun(@(s) parseContractCode(s), uName);

    raw.date      = [raw.date;      datenum(T.date)];
    raw.code      = [raw.code;      uCode(ic(:))];
    raw.isCall    = [raw.isCall;    strcmp(string(T.option_type), "Call")];
    raw.strike    = [raw.strike;    double(T.strike)];
    raw.optBid    = [raw.optBid;    double(T.option_bid)];
    raw.optAsk    = [raw.optAsk;    double(T.option_ask)];
    raw.optSettle = [raw.optSettle; double(T.settlement_price)];
    raw.expiry    = [raw.expiry;    datenum(T.expiration)];
    raw.futSettle = [raw.futSettle; double(T.underlying_settlement)];
    raw.futBid    = [raw.futBid;    double(T.underlying_bid)];
    raw.futAsk    = [raw.futAsk;    double(T.underlying_ask)];
    raw.sofrPct   = [raw.sofrPct;   double(T.sofr_rate)];
end

data = buildInternalData(raw);
end
