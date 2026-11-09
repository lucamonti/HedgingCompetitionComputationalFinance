function data = makeSyntheticData(cfg)
%MAKESYNTHETICDATA Simulated dataset in the internal format of loadData.m.
% Only to check that the code runs end to end before the real data is wired
% in: two correlated GBM futures, a fixed skewed smile for the options, a
% simple SOFR curve. NOT market data: the numbers mean nothing.

setSeed(cfg.mcSeed + 1);
lastDay = datenum(cfg.avgYear, cfg.avgMonth, eomday(cfg.avgYear, cfg.avgMonth)) + 30;
days  = (cfg.tStart:lastDay)';
dates = days(isBusinessDay(days, cfg.holidays));
T     = numel(dates);
codes = [cfg.leg1 cfg.leg2];

% ---- futures: two correlated driftless GBMs ----
f0  = [62 61.5];
sig = [0.32 0.31];
rho = 0.98;
dt  = [0; diff(dates)] / 365;
z1  = randn(T, 1);
z2  = rho * z1 + sqrt(1 - rho^2) * randn(T, 1);
lr  = [sig(1) * sqrt(dt) .* z1 - 0.5 * sig(1)^2 * dt, ...
       sig(2) * sqrt(dt) .* z2 - 0.5 * sig(2)^2 * dt];
settle = round(100 * f0 .* exp(cumsum(lr))) / 100;
futLTD1 = iceBrentExpiry(codes(1), cfg.holidays);
settle(dates > futLTD1, 1) = NaN;              % leg 1 stops trading at expiry
data.fut.dates  = dates;
data.fut.codes  = codes;
data.fut.settle = settle;

% ---- options: fixed skewed smile, settlement = model price, bid/ask around it ----
K  = (20:2.5:130)';
nK = numel(K);
blocks = cell(T, 2);
for j = 1:T
    for i = 1:2
        [~, optLTD] = iceBrentExpiry(codes(i), cfg.holidays);
        tau = (optLTD - dates(j)) / 365;
        F = settle(j, i);
        if tau <= 0 || isnan(F)
            continue
        end
        x   = log(K / F);
        iv  = max(0.30 - 0.10 * x + 0.15 * x.^2, 0.10);
        KK  = [K; K];
        isC = [true(nK, 1); false(nK, 1)];
        p   = round(100 * black76(F, KK, [iv; iv], tau, isC)) / 100;
        spr = max(0.02, 0.06 * p);
        bid = max(round(100 * (p - spr/2)) / 100, 0);
        ask = round(100 * (p + spr/2)) / 100;
        keep = rand(2*nK, 1) > 0.3;             % random missing strikes
        n = sum(keep);
        blocks{j, i} = [dates(j) * ones(n, 1), codes(i) * ones(n, 1), isC(keep), ...
                        KK(keep), bid(keep), ask(keep), p(keep), optLTD * ones(n, 1)];
    end
end
Q = vertcat(blocks{:});
data.opt.date   = Q(:, 1);
data.opt.code   = Q(:, 2);
data.opt.isCall = logical(Q(:, 3));
data.opt.strike = Q(:, 4);
data.opt.bid    = Q(:, 5);
data.opt.ask    = Q(:, 6);
data.opt.settle = Q(:, 7);
data.opt.expiry = Q(:, 8);

% ---- SOFR: overnight rate that drops in March 2020 ----
data.sofr.dates = dates;
data.sofr.rate  = 0.0155 * ones(T, 1);
data.sofr.rate(dates >= datenum(2020, 3, 16)) = 0.0005;
end
