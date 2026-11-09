function [C, P, out] = basketMM(F, sig, rho, theta, legOf, knownSum, N, K, D)
%BASKETMM Moment-matching price of a call and a put on the arithmetic average
%   A = ( knownSum + sum_k f(t_k, tau_leg(k)) ) / N
% (Note, Sections 4-6). Fixings already observed enter through knownSum: this
% is needed to reprice the collar inside the averaging month, which the Note
% does not cover (it prices at a date before the first fixing).
%
%   F        : 1x2 current futures prices [f(t,tau1) f(t,tau2)]
%   sig      : 1x2 volatilities [sigma1 sigma2]
%   rho      : correlation between the two legs
%   theta    : year fractions t_k - t of the fixings still to come (> 0)
%   legOf    : leg (1 or 2) of each fixing still to come
%   knownSum : sum of the fixings already observed (0 before the first fixing)
%   N        : total number of fixings
%   K        : strike (scalar)
%   D        : discount factor to the payment date
%
% The random part of A is a sum of correlated lognormals. Its first two
% moments are computed exactly and matched to a lognormal; the fixed part
% shifts the strike: max(A - K, 0) = max(Arand - Keff, 0), Keff = K - knownSum/N.
% Before the first fixing this is exactly Eqs. (19)-(24) of the Note; the
% double sum below equals the closed forms (15), (16), (18), (20)
% (checked in validatePricers.m).

theta = theta(:);
legOf = legOf(:);
nf    = numel(theta);
fixedPart = knownSum / N;
Keff  = K - fixedPart;
out   = struct('m', NaN, 'varA', NaN, 'v', NaN, 'Keff', Keff);

if nf == 0                                    % every fixing known: payoff known
    C = D * max(fixedPart - K, 0);
    P = D * max(K - fixedPart, 0);
    return
end

a  = ones(nf, 1) / N;                         % weight of each fixing
Fk = F(legOf);  Fk = Fk(:);                   % forward of each fixing
sk = sig(legOf); sk = sk(:);                  % vol of each fixing
R  = ones(nf);
R(legOf ~= legOf') = rho;                     % correlation between fixings' legs
Cov = (sk * sk') .* R .* min(theta, theta');  % Cov of log-fixings, Note Eq. (8)

m    = a' * Fk;                                     % E[random part], Eqs. (12), (19)
varA = a' * ((Fk * Fk') .* (exp(Cov) - 1)) * a;     % Var, Eqs. (13)-(20)
out.m = m;
out.varA = varA;

if Keff <= 0                                  % the call is certainly exercised
    C = D * (m - Keff);
    P = 0;
    return
end

v  = sqrt(log(1 + varA / m^2));               % Eq. (21)
out.v = v;
d1 = (log(m / Keff) + 0.5 * v^2) / v;         % Eq. (24)
d2 = d1 - v;
C  = D * (m * normCdf(d1) - Keff * normCdf(d2));     % Eq. (22)
P  = D * (Keff * normCdf(-d2) - m * normCdf(-d1));   % Eq. (23)

% [ROBUST] Matching two moments to a lognormal (Levy, 1992) is accurate near
%          the money but less so in the tails, i.e. exactly where Kput and 78
%          sit. Compare with Monte Carlo at the actual strikes (validatePricers.m)
%          and, if the gap matters, match more moments (Turnbull-Wakeman,
%          Ju 2002) or price with Monte Carlo.
end
