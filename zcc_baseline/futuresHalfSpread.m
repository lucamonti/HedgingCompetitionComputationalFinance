function hs = futuresHalfSpread(fut, j, col, cfg)
%FUTURESHALFSPREAD Half bid-ask spread (USD/bbl) of the two hedge futures on
% date index j. Uses the quoted bid/ask if loadData.m provided them,
% otherwise cfg.futHalfSpread.
hs = cfg.futHalfSpread * [1 1];
if isfield(fut, 'bid') && isfield(fut, 'ask')
    q  = (fut.ask(j, col) - fut.bid(j, col)) / 2;
    ok = ~isnan(q) & q > 0;
    hs(ok) = q(ok);
end
end
