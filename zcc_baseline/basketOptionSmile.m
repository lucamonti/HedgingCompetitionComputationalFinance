function [price, sig] = basketOptionSmile(K, isCall, mkt)
%BASKETOPTIONSMILE Price per bbl of a call or put with strike K on the
% average, with sigma_1 and sigma_2 read off the two smiles at the equivalent
% single-name strikes K_i = f_i * K / F_avg (Note, Eqs. (4)-(6)).
%
%   mkt: struct with fields F, sm, rho, N, knownSum, theta, legOf, D
%        (built in main.m at every rebalancing date)
%
% Since K_i / f_i = K / F_avg, both smiles are read at the same log-moneyness
% x = ln(K / F_avg). Inside the averaging month part of the average is already
% fixed, and the option is an option on the remaining random part (expected
% value m) with strike Keff = K - fixed part; there we use x = ln(Keff / m).
% Before the first fixing this is exactly the Note's ln(K / F_avg).
%
% [ROBUST] Two modelling choices sit here:
%   1) the Note's sticky-moneyness mapping of the basket strike onto each leg;
%   2) one constant vol per leg for all fixing dates, read off options whose
%      expiry differs from the fixing dates. A vol term structure (variance
%      accumulated up to each fixing date) is more accurate when the options'
%      expiry is far from the fixings.

fixedPart = mkt.knownSum / mkt.N;
m    = sum(mkt.F(mkt.legOf)) / mkt.N;
Keff = K - fixedPart;
if isempty(mkt.legOf) || Keff <= 0
    x = 0;                   % payoff already determined: the vol is irrelevant
else
    x = log(Keff / m);
end
sig = [smileVol(mkt.sm{1}, x), smileVol(mkt.sm{2}, x)];
[C, P] = basketMM(mkt.F, sig, mkt.rho, mkt.theta, mkt.legOf, mkt.knownSum, mkt.N, K, mkt.D);
if isCall
    price = C;
else
    price = P;
end
end
