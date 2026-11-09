function [sm, nUsed] = calibrateSmile(q, F, tau, cfg)
%CALIBRATESMILE Filter the option quotes of one contract on one day, invert
% the undiscounted Black-76 formula and fit a quadratic smile in log-moneyness.
%
%   q     : struct with column vectors strike, isCall, bid, ask, settle
%   F     : settlement of the underlying futures on that day
%   tau   : time to option expiry in years (ACT/365)
%   sm    : fitted smile (empty if no usable quote), evaluated by smileVol.m
%   nUsed : number of quotes that survive the filters
%
% Early exercise (Task 2 asks to justify this). ICE Brent options are American
% but futures-style margined: no premium is paid at trade date and the option
% is marked to market daily, so exercising early earns no interest. The
% undiscounted European value satisfies E[(F_T - K)+] >= (F_t - K)+ (Jensen's
% inequality, F is a martingale), so early exercise is never optimal and the
% American price equals the undiscounted Black-76 price (Asay, 1982; Chen and
% Scott, 1993). The early-exercise premium is therefore set to zero.

sm = [];
nUsed = 0;
if tau * 365 < cfg.minTauDays || isempty(q.strike)
    return
end

K      = q.strike;
isCall = logical(q.isCall);
bid    = q.bid;
ask    = q.ask;
mid    = 0.5 * (bid + ask);
hasBA  = bid > 0 & ask > bid;          % a usable bid/ask quote (NaN -> false)

% ---- price used for the implied vol: the exchange settlement price ----
% In this dataset the settlement price equals the bid/ask mid whenever both
% exist, and after 1 Jun 2020 there are only settlement prices. Using the
% settlement on every day keeps a single, consistent price source.
price = q.settle;
useMid = ~(price > 0) & hasBA;         % no settlement but a quote: use the mid
price(useMid) = mid(useMid);

% ---- liquidity filter ----
keep = price >= cfg.minMid;            % NaN prices are dropped here
% bid/ask spread filter, where a quote exists
keep = keep & (~hasBA | (ask - bid) ./ mid <= cfg.maxRelSpread);
% [ROBUST] After 1 Jun 2020 the dataset has no option bid/ask, so the spread
%          filter cannot be applied and every settlement price is kept. ICE
%          settles illiquid strikes from its own vol surface, so these prices
%          are smooth but not traded. A moneyness band (e.g. |ln(K/F)| < 0.4)
%          is a simple substitute for the missing liquidity information.
if cfg.otmOnly
    % OTM options are the liquid ones and have no intrinsic value, so their
    % price is informative about volatility only.
    keep = keep & ((isCall & K >= F) | (~isCall & K < F));
end
% no-arbitrage: the price must exceed the intrinsic value
intrinsic = max(F - K, 0) .* isCall + max(K - F, 0) .* ~isCall;
keep = keep & price > intrinsic;
% [ROBUST] Further filters worth considering: stale prices (unchanged for
%          several days), minimum volume or open interest (not in this
%          dataset), butterfly and call-spread arbitrage checks across strikes.

if ~any(keep)
    return
end
K      = K(keep);
price  = price(keep);
isCall = isCall(keep);

% ---- implied volatilities: undiscounted Black-76 (r = 0) ----
iv = impliedVolB76(price, F, K, tau, isCall, cfg.ivBounds);
ok = ~isnan(iv);
K  = K(ok);
iv = iv(ok);
nUsed = numel(iv);
if nUsed == 0
    return
end
% [ROBUST] Only one price per strike is inverted. Where bid/ask exist,
%          inverting them separately gives an IV band per strike, and the fit
%          below could weight each strike by 1/(IV_ask - IV_bid) or by its
%          Black-76 vega.
% [ROBUST] Futures settlements and option quotes may not be taken at the same
%          time of day; with a non-synchronous F the implied vols are biased,
%          especially away from the money.

% ---- fit sigma(x) = c2*x^2 + c1*x + c0, with x = ln(K/F) ----
x = log(K ./ F);
if numel(unique(x)) >= cfg.minStrikesFit
    coef = polyfit(x, iv, 2);
else
    coef = [0 0 mean(iv)];              % too few strikes: flat smile
end
% [ROBUST] A quadratic is the simplest smile. It is not arbitrage-free and it
%          can change shape from one day to the next when quotes enter or
%          leave the filter. Every jump in the fitted smile moves the collar
%          value, i.e. it becomes P&L that no hedge can offset. More robust:
%          SVI or SABR fitted every day starting from the previous day's
%          parameters, or a penalty on day-to-day parameter changes.

sm.coef     = coef;
sm.xmin     = min(x);
sm.xmax     = max(x);
sm.volFloor = cfg.ivBounds(1);
sm.F        = F;
sm.tau      = tau;
end
