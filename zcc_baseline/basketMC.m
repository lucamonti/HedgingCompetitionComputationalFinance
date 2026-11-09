function out = basketMC(F, sig, rho, theta, legOf, knownSum, knownLogSum, N, K, D, M, seed)
%BASKETMC Exact bivariate lognormal Monte Carlo of the average (Note, Sec. 5)
% with the geometric-average control variate (Note, Sec. 5.3).
%   Inputs as in basketMM.m, plus
%   knownLogSum : sum of the logs of the fixings already observed
%   M, seed     : number of paths and random seed
%   out         : plain MC prices C, P and standard errors seC, seP;
%                 control-variate prices Ccv, Pcv and seCcv, sePcv;
%                 exact geometric prices Cgeo, Pgeo;
%                 MC geometric prices on the same paths CgeoMC, PgeoMC.
%
% No time discretisation: ln f is Gaussian, so we jump straight to the fixing
% dates. The only error is statistical, of order 1/sqrt(M).
%
% [ROBUST] If you use Monte Carlo as the daily pricer (e.g. for an extended
%          model), use the same seed every day (common random numbers) and the
%          same paths for the bumped prices in the deltas. Otherwise simulation
%          noise moves the collar value from day to day and becomes P&L.

theta = theta(:);
legOf = legOf(:);
nf = numel(theta);
if nf == 0
    error('basketMC: no fixing left to simulate.');
end
Fk = F(legOf);  Fk = Fk(:);
sk = sig(legOf); sk = sk(:);
R  = ones(nf);
R(legOf ~= legOf') = rho;
Sig = (sk * sk') .* R .* min(theta, theta');   % Note, Eq. (8)
mu  = -0.5 * sk.^2 .* theta;                    % Note, Eq. (7)
a   = ones(nf, 1) / N;
L   = chol(Sig, 'lower');

% exact price of the option on the geometric average, Note Eqs. (9)-(11)
mG   = knownLogSum / N + a' * (log(Fk) + mu);
vG2  = a' * Sig * a;
vG   = sqrt(vG2);
Fgeo = exp(mG + 0.5 * vG2);
d1   = (log(Fgeo / K) + 0.5 * vG2) / vG;
d2   = d1 - vG;
out.Cgeo = D * (Fgeo * normCdf(d1) - K * normCdf(d2));
out.Pgeo = D * (K * normCdf(-d2) - Fgeo * normCdf(-d1));

% simulation in batches (one matrix product per batch, no loop over paths)
setSeed(seed);
nS = 6;                % payoff series: cA, pA, cA-cG, pA-pG, cG, pG
S  = zeros(1, 2*nS);   % their sums and sums of squares
batch = 1e5;
done  = 0;
while done < M
    nb  = min(batch, M - done);
    eta = mu + L * randn(nf, nb);                      % log-increments, nf x nb
    A   = knownSum / N + a' * (Fk .* exp(eta));        % arithmetic average
    G   = exp(knownLogSum / N + a' * (log(Fk) + eta)); % geometric average
    cA = max(A - K, 0);  pA = max(K - A, 0);
    cG = max(G - K, 0);  pG = max(K - G, 0);
    Y  = [cA; pA; cA - cG; pA - pG; cG; pG];
    S  = S + [sum(Y, 2)', sum(Y.^2, 2)'];
    done = done + nb;
end
mn = S(1:nS) / M;
sd = sqrt(max(S(nS+1:end) / M - mn.^2, 0) * M / (M - 1));
se = D * sd / sqrt(M);

out.C      = D * mn(1);               out.seC   = se(1);
out.P      = D * mn(2);               out.seP   = se(2);
out.Ccv    = D * mn(3) + out.Cgeo;    out.seCcv = se(3);   % Note, Eq. (11)
out.Pcv    = D * mn(4) + out.Pgeo;    out.sePcv = se(4);
out.CgeoMC = D * mn(5);
out.PgeoMC = D * mn(6);
end
