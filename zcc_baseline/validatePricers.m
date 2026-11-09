function validatePricers(mkt, Kput, cfg)
%VALIDATEPRICERS Checks run once at inception (Note, Sections 5.3, 5.4, 6.7).
%   1) implied-vol round trip
%   2) moment matching with a single fixing = Black-76
%   3) Monte Carlo with a single fixing converges to Black-76 (across maturities)
%   4) basket at inception: moment matching vs Monte Carlo (plain and with
%      control variate), and the AM-GM sanity check
%   5) the matrix variance in basketMM = the Note's closed-form sums
%   6) h(K) = Put(K) - Call(Kcall) is increasing (needed by the bisection)

fprintf('\n=============== Pricer validation at inception ===============\n');
F = mkt.F(1);
s = smileVol(mkt.sm{1}, 0);              % ATM vol of leg 1, for the vanilla tests

%% 1) Implied-vol round trip
K = F * [0.6 0.8 1.0 1.2 1.5]';
sigTrue = [0.45 0.36 0.30 0.28 0.31]';
isC = K >= F;
p = black76(F, K, sigTrue, 1.1, isC);
sigBack = impliedVolB76(p, F, K, 1.1, isC, cfg.ivBounds);
fprintf('1) Implied-vol round trip: max |error| = %.1e\n', max(abs(sigBack - sigTrue)));

%% 2) Moment matching, one fixing on one leg = Black-76 (Note, Eq. (25))
err = 0;
for T = [0.25 0.5 1 2]
    for Kk = F * [0.7 1 1.3]
        [C1, P1] = basketMM([F F], [s s], mkt.rho, T, 1, 0, 1, Kk, 1);
        err = max([err, abs(C1 - black76(F, Kk, s, T, true)), ...
                        abs(P1 - black76(F, Kk, s, T, false))]);
    end
end
fprintf('2) Moment matching, single fixing vs Black-76: max |error| = %.1e\n', err);

%% 3) Monte Carlo, one fixing -> Black-76 as the number of paths grows (Sec. 5.4)
fprintf('3) Monte Carlo, single fixing, ATM call vs Black-76:\n');
fprintf('   %5s %9s %10s %10s %9s %10s\n', 'T', 'paths', 'MC', 'Black-76', 'SE', 'within');
for T = [0.25 1 2]
    bs = black76(F, F, s, T, true);
    for M = [1e3 1e4 1e5 1e6]
        o = basketMC([F F], [s s], mkt.rho, T, 1, 0, 0, 1, F, 1, M, cfg.mcSeed);
        fprintf('   %5.2f %9d %10.4f %10.4f %9.4f %10s\n', T, M, o.C, bs, o.seC, ...
            yesNo(abs(o.C - bs) <= 1.96 * o.seC, '1.96 SE', 'NO'));
    end
end

%% 4) Basket at inception: moment matching vs Monte Carlo
if mkt.knownSum == 0
    fprintf('4) Basket options at inception, %d paths (USD/bbl):\n', cfg.mcPaths);
    fprintf('   %-12s %8s %8s %9s %8s %9s %11s %6s\n', 'option', 'MM', 'MC', 'SE', ...
        'MC+CV', 'SE(CV)', 'MM-(MC+CV)', 'AM-GM');
    opts = {'Put(Kput)', Kput, false; 'Call(Kcall)', cfg.Kcall, true};
    for c = 1:2
        Kc = opts{c, 2};
        isCall = opts{c, 3};
        [pMM, sigUsed] = basketOptionSmile(Kc, isCall, mkt);
        o = basketMC(mkt.F, sigUsed, mkt.rho, mkt.theta, mkt.legOf, 0, 0, ...
                     mkt.N, Kc, mkt.D, cfg.mcPaths, cfg.mcSeed);
        if isCall
            row = [pMM o.C o.seC o.Ccv o.seCcv pMM - o.Ccv];
            amgm = o.C >= o.CgeoMC;     % arithmetic call >= geometric call
        else
            row = [pMM o.P o.seP o.Pcv o.sePcv pMM - o.Pcv];
            amgm = o.P <= o.PgeoMC;     % arithmetic put <= geometric put
        end
        fprintf('   %-12s %8.4f %8.4f %9.2e %8.4f %9.2e %11.2e %6s\n', opts{c, 1}, row, ...
            yesNo(amgm, 'ok', 'FAIL'));
    end
    fprintf('   The control variate makes MC precise enough to see the moment-matching\n');
    fprintf('   error (last column): compare it with the size of the daily P&L.\n');
end

%% 5) Matrix variance in basketMM = closed-form sums of the Note
n1 = sum(mkt.legOf == 1);
n2 = sum(mkt.legOf == 2);
if mkt.knownSum == 0 && n1 > 0 && n2 > 0
    [~, sg] = basketOptionSmile(cfg.Kcall, true, mkt);
    f1 = mkt.F(1);  f2 = mkt.F(2);
    th1 = mkt.theta(mkt.legOf == 1);
    th2 = mkt.theta(mkt.legOf == 2);
    k = (1:n1)';
    j = (1:n2)';
    varA1 = f1^2 / n1^2 * sum((2*(n1 - k) + 1) .* (exp(sg(1)^2 * th1) - 1));   % Eq. (15)
    varA2 = f2^2 / n2^2 * sum((2*(n2 - j) + 1) .* (exp(sg(2)^2 * th2) - 1));   % Eq. (16)
    cov12 = f1 * f2 / n1 * sum(exp(mkt.rho * sg(1) * sg(2) * th1) - 1);       % Eq. (18)
    w1 = n1 / mkt.N;
    w2 = n2 / mkt.N;
    varNote = w1^2 * varA1 + w2^2 * varA2 + 2 * w1 * w2 * cov12;              % Eq. (20)
    [~, ~, o] = basketMM(mkt.F, sg, mkt.rho, mkt.theta, mkt.legOf, 0, mkt.N, cfg.Kcall, 1);
    fprintf('5) Var(A): Note closed form %.6f, matrix form %.6f, rel. diff %.1e\n', ...
        varNote, o.varA, abs(varNote - o.varA) / varNote);
end

%% 6) h(K) = Put(K) - Call(Kcall) increasing in K (Note, Sec. 7, point 4)
Cstar = basketOptionSmile(cfg.Kcall, true, mkt);
Favg  = sum(mkt.F(mkt.legOf)) / mkt.N;
Kgrid = linspace(0.3, 1.2, 91) * Favg;
hK = zeros(size(Kgrid));
for k = 1:numel(Kgrid)
    hK(k) = basketOptionSmile(Kgrid(k), false, mkt) - Cstar;
end
nRoots = sum(diff(sign(hK)) ~= 0);
fprintf('6) h(K) = Put(K) - Call(Kcall) on [0.3, 1.2] x F_avg: increasing %s, sign changes %d (bisection needs 1)\n', ...
    yesNo(all(diff(hK) > 0), 'yes', 'NO'), nRoots);
if ~all(diff(hK) > 0)
    kBad = find(diff(hK) <= 0, 1);
    fprintf('   first decrease at K = %.2f: the smile wing is steep enough to create\n', Kgrid(kBad));
    fprintf('   a strike arbitrage there. Harmless if far from Kput, otherwise fix the wing fit.\n');
end
fprintf('===============================================================\n\n');
end

function s = yesNo(cond, sYes, sNo)
if cond
    s = sYes;
else
    s = sNo;
end
end
