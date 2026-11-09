function [Kput, Cstar] = solveKput(mkt, cfg)
%SOLVEKPUT Zero-cost put strike: Put(Kput) = Call(Kcall), by bisection
% (Note, Section 7). For every trial strike the vols are re-read off the
% smiles at the mapped strikes (inside basketOptionSmile), as the Note says.

Cstar = basketOptionSmile(cfg.Kcall, true, mkt);
h = @(K) basketOptionSmile(K, false, mkt) - Cstar;

Favg = (mkt.knownSum + sum(mkt.F(mkt.legOf))) / mkt.N;
lo = 1e-3 * Favg;
hi = Favg;                          % Note: initial bracket [0, F_avg]
it = 0;
while h(hi) < 0 && it < 20          % only needed if the call is in the money
    hi = 2 * hi;
    it = it + 1;
end
if h(lo) > 0 || h(hi) < 0
    error('solveKput: no sign change in the bracket.');
end
for it = 1:200
    mid = 0.5 * (lo + hi);
    if h(mid) > 0
        hi = mid;
    else
        lo = mid;
    end
    if hi - lo < 1e-8
        break
    end
end
Kput = 0.5 * (lo + hi);
% [CHECK] Bisection assumes h is increasing in K. validatePricers.m checks it
%         on a grid at inception, as the Note recommends.
end
