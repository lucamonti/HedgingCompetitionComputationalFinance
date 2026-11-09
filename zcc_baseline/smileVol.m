function v = smileVol(sm, x)
%SMILEVOL Volatility read off a fitted smile at log-moneyness x = ln(K/F).
% Flat extrapolation outside the range of quoted strikes.
% [ROBUST] Flat wings are the simplest safe choice: a quadratic extrapolated
%          far outside the data can explode or turn negative. SVI or SABR
%          have sensible wings by construction.
xc = min(max(x, sm.xmin), sm.xmax);
v  = max(polyval(sm.coef, xc), sm.volFloor);
end
