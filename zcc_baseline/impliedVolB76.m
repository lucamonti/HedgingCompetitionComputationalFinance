function iv = impliedVolB76(price, F, K, tau, isCall, bounds)
%IMPLIEDVOLB76 Implied volatility from the undiscounted Black-76 formula, by
% vectorized bisection. NaN when the price is outside the range spanned by
% the vol bounds (e.g. below intrinsic value).
%   price, K, isCall : column vectors (one entry per quote)
%   F, tau           : scalars (one underlying, one expiry)
%   bounds           : [minVol maxVol]

price  = price(:);
K      = K(:);
isCall = logical(isCall(:));
n  = numel(price);
lo = bounds(1) * ones(n, 1);
hi = bounds(2) * ones(n, 1);
ok = price > black76(F, K, lo, tau, isCall) & price < black76(F, K, hi, tau, isCall);

for it = 1:60                       % bracket width / 2^60: far below any tolerance
    md = 0.5 * (lo + hi);
    tooLow = black76(F, K, md, tau, isCall) < price;   % price increases with sigma
    lo(tooLow)  = md(tooLow);
    hi(~tooLow) = md(~tooLow);
end
iv = 0.5 * (lo + hi);
iv(~ok) = NaN;
end
