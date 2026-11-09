function D = discountFactor(sofr, t, T)
%DISCOUNTFACTOR D(t,T) from the SOFR rate observed on date t (or the last
% one before t, so that no future data is used).
% The dataset gives one overnight SOFR rate per date (ACT/360), not a curve,
% so the rate is held flat until T: D = exp(-r * (T - t) / 360). Over one day
% this is the overnight accrual used for the cash account.

if T <= t
    D = 1;
    return
end
i = find(sofr.dates <= t, 1, 'last');
if isempty(i)
    i = 1;   % [CHECK] no rate on or before t: the first available one is used
end
D = exp(-sofr.rate(i) * (T - t) / 360);
% [ROBUST] A flat overnight rate ignores the term structure. In January 2020
%          (SOFR about 1.55%) it matters for the 13-month discount factor; after
%          March 2020 rates are near zero and it hardly does. A curve
%          bootstrapped from SOFR futures or swaps would be the proper input.
end
