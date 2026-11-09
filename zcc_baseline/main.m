%% CALIBRATION AND HEDGING LAB - Asian/basket zero-cost collar on ICE Brent
% Baseline ("plain") implementation of the assignment, following the note
% "Pricing the Energy Asian/Basket Zero-Cost Collar" (Targa, Sabino).
%
%   Task 2  implied vols from the undiscounted Black-76 formula (r = 0),
%           early-exercise premium set to zero (justified in calibrateSmile.m),
%           liquidity filter, one quadratic smile per leg, refitted every day
%   Task 3  two driftless correlated GBMs (Black-76), one vol per leg;
%           rho = rolling correlation of daily log-returns, re-estimated daily
%           [ROBUST] The optional extensions (jump HJM, Heston on the spot)
%           would replace basketOptionSmile/basketMM with a Monte Carlo pricer;
%           everything else in this script stays the same.
%   Task 4  moment matching (closed form) as the pricer; Monte Carlo with the
%           geometric control variate only to validate it
%   Task 5  Kput by bisection so that Put(Kput) = Call(78) at inception
%   Task 6  delta hedge on both legs with the two futures, rebalanced daily,
%           paying the bid-ask spread; cash earns/pays the SOFR rate
%   Task 7  every day: recalibrate, reprice, compute P&L, rebalance
%
% Comment tags (search the whole folder with Home tab > Find Files):
%   [ROBUST]  the baseline could be improved or made more robust here
%   [CHECK]   assumption to verify (data, ICE calendar, instructors)
%   [ADAPT]   depends on the format of the dataset files
%
% Dates are datenums (doubles) so the code runs in MATLAB and GNU Octave.
% Use datestr(d) to read one, or datetime(d, 'ConvertFrom', 'datenum').

clear; close all; clc;

%% 1. Settings
cfg = setupConfig('train');          % 'train' (Feb21 collar) or 'test' (Oct22 collar)
% cfg.useSyntheticData = true;       % uncomment to test the pipeline on fake data

%% 2. Data
if cfg.useSyntheticData
    data = makeSyntheticData(cfg);
else
    data = loadData(cfg);            % reads cfg.dataFiles from cfg.dataDir
end

legCode = [cfg.leg1 cfg.leg2];
col = [find(data.fut.codes == cfg.leg1, 1), find(data.fut.codes == cfg.leg2, 1)];
if numel(col) ~= 2
    error('Futures %s and/or %s not found in the data.', ...
        contractName(cfg.leg1), contractName(cfg.leg2));
end

% Keep only the option quotes we need: the two legs, inside the backtest window
keepOpt = ismember(data.opt.code, legCode) & ...
          data.opt.date >= cfg.tStart & data.opt.date <= cfg.tEnd;
opt = subsetRows(data.opt, keepOpt);

%% 3. Fixing schedule and expiries (Annex B)
sched = fixingSchedule(cfg);

% Option expiries: from the dataset if available, otherwise from the ICE rule
optExpiry = zeros(1, 2);
for i = 1:2
    [~, ruleExp] = iceBrentExpiry(legCode(i), cfg.holidays);
    e = [];
    if isfield(data.opt, 'expiry')
        e = unique(data.opt.expiry(data.opt.code == legCode(i) & ~isnan(data.opt.expiry)));
    end
    if numel(e) == 1
        optExpiry(i) = e;
    else
        optExpiry(i) = ruleExp;
    end
    fprintf('%s options expire %s (ICE rule: %s)\n', contractName(legCode(i)), ...
        datestr(optExpiry(i), 'dd-mmm-yyyy'), datestr(ruleExp, 'dd-mmm-yyyy'));
end

fprintf('Averaging month: %d fixings, %d on %s and %d on %s\n', sched.N, ...
    sched.n1, contractName(cfg.leg1), sched.n2, contractName(cfg.leg2));
fprintf('Last %s fixing: %s | %s futures expiry: %s | payment date: %s\n', ...
    contractName(cfg.leg1), datestr(sched.lastLeg1, 'dd-mmm-yyyy'), ...
    contractName(cfg.leg1), datestr(sched.futLTD1, 'dd-mmm-yyyy'), ...
    datestr(sched.T, 'dd-mmm-yyyy'));

% Settlement prices on the fixing dates. A fixing is only used once its date
% is <= the valuation date, so there is no look-ahead.
fixValue = NaN(sched.N, 1);
for k = 1:sched.N
    r = find(data.fut.dates == sched.fixDates(k), 1);
    if ~isempty(r)
        fixValue(k) = data.fut.settle(r, col(sched.leg(k)));
    end
end
% [CHECK] A fixing with no settlement in the data takes the last earlier
%         settlement of the same contract. With the literal roll rule this
%         happens for the last Apr21 fixing (24 Feb 2021), because the dataset
%         has no Apr21 settlement after 23 Feb. Replace it with the true ICE
%         settlement if you can get it, or change the roll rule (setupConfig.m).
for k = find(isnan(fixValue))'
    c = col(sched.leg(k));
    r = find(data.fut.dates < sched.fixDates(k) & ~isnan(data.fut.settle(:, c)), 1, 'last');
    if isempty(r)
        continue        % fixing date beyond the data: handled in the loop
    end
    fixValue(k) = data.fut.settle(r, c);
    warning('Fixing %s (%s) missing in the data: using the %s settlement %.2f.', ...
        datestr(sched.fixDates(k), 'dd-mmm-yyyy'), contractName(legCode(sched.leg(k))), ...
        datestr(data.fut.dates(r), 'dd-mmm-yyyy'), fixValue(k));
end

%% 4. Backtest
bt = find(data.fut.dates >= cfg.tStart & data.fut.dates <= cfg.tEnd);
nT = numel(bt);
if data.fut.dates(bt(1)) ~= cfg.tStart
    warning('First data date (%s) differs from the emission date.', ...
        datestr(data.fut.dates(bt(1))));
end

res.date     = data.fut.dates(bt);
res.F        = NaN(nT, 2);    % futures settlements
res.rho      = NaN(nT, 1);
res.sigPut   = NaN(nT, 2);    % vols used for the put (leg 1, leg 2)
res.sigCall  = NaN(nT, 2);    % vols used for the call
res.nQuotes  = zeros(nT, 2);  % option quotes surviving the filters
res.P        = NaN(nT, 1);    % Put(Kput), USD/bbl
res.C        = NaN(nT, 1);    % Call(Kcall), USD/bbl
res.V        = NaN(nT, 1);    % collar value for the market maker, USD
res.delta    = NaN(nT, 2);    % dV/df_i, bbl
res.pos      = NaN(nT, 2);    % futures held after rebalancing, bbl
res.futPnL   = zeros(nT, 1);
res.interest = zeros(nT, 1);
res.cost     = zeros(nT, 1);
res.cash     = NaN(nT, 1);
res.Pi       = NaN(nT, 1);    % portfolio value = V + cash
res.PnL      = NaN(nT, 1);    % daily P&L

smPrev = {[], []};
pos    = [0 0];
cash   = 0;
PiPrev = 0;

for s = 1:nT
    j = bt(s);
    t = data.fut.dates(j);

    % ---- (a) futures settlements ----
    F = data.fut.settle(j, col);
    if any(isnan(F))
        % [ROBUST] A missing settlement is carried forward from the previous
        %          day. In this dataset it happens to leg 1 after its options
        %          expire (Apr21 after 23 Feb 2021), when its weight is small or
        %          zero. Better: get the true settlements and check each gap.
        if s == 1, error('Missing futures settlement at inception.'); end
        F(isnan(F)) = Fprev(isnan(F));
    end

    % ---- (b) recalibrate the two smiles (Task 2) ----
    sm = cell(1, 2);
    for i = 1:2
        tau = (optExpiry(i) - t) / 365;
        q = getOptionQuotes(opt, t, legCode(i));
        [sm{i}, res.nQuotes(s, i)] = calibrateSmile(q, F(i), tau, cfg);
        if isempty(sm{i})
            % [ROBUST] No usable quotes today (illiquid day, or the options
            %          have expired while the futures still fixes): keep
            %          yesterday's smile. Alternatives: borrow the smile of the
            %          neighbouring contract, or use a vol term structure.
            sm{i} = smPrev{i};
        end
        if isempty(sm{i})
            error('No usable option quotes for %s on %s.', ...
                contractName(legCode(i)), datestr(t));
        end
    end
    smPrev = sm;

    % ---- (c) re-estimate the correlation (Task 3) ----
    rho = estimateRho(data.fut, j, col, cfg);

    % ---- (d) state of the averaging, discounting ----
    known = sched.fixDates <= t;
    if any(isnan(fixValue(known)))
        error('Missing settlement on a past fixing date (valuation date %s).', datestr(t));
    end
    mkt.F        = F;
    mkt.sm       = sm;
    mkt.rho      = rho;
    mkt.N        = sched.N;
    mkt.knownSum = sum(fixValue(known));
    mkt.theta    = (sched.fixDates(~known) - t) / 365;   % ACT/365, as for the options
    mkt.legOf    = sched.leg(~known);
    mkt.D        = discountFactor(data.sofr, t, sched.T);

    % ---- (e) inception: zero-cost put strike (Task 5) ----
    if s == 1
        [Kput, Cstar] = solveKput(mkt, cfg);
        [V0, parts0] = collarValue(mkt, Kput, cfg);
        delta0 = collarDelta(mkt, Kput, cfg);
        fprintf('\n=============== Inception %s ===============\n', datestr(t, 'dd-mmm-yyyy'));
        fprintf('%s = %.2f, %s = %.2f | rho = %.3f | D(t,T) = %.4f\n', ...
            contractName(cfg.leg1), F(1), contractName(cfg.leg2), F(2), rho, mkt.D);
        fprintf('Option quotes used: %d on %s, %d on %s\n', res.nQuotes(1, 1), ...
            contractName(cfg.leg1), res.nQuotes(1, 2), contractName(cfg.leg2));
        fprintf('Call(%.2f)      = %.4f USD/bbl (vols %.2f%%, %.2f%%)\n', ...
            cfg.Kcall, parts0.C, 100*parts0.sigCall);
        fprintf('Kput = %.4f, Put = %.4f USD/bbl (vols %.2f%%, %.2f%%)\n', ...
            Kput, parts0.P, 100*parts0.sigPut);
        fprintf('Collar value for the market maker: %.2f USD (zero by construction)\n', round(V0*100)/100 + 0);
        fprintf('Initial hedge: buy %.0f bbl %s (%.1f lots) and %.0f bbl %s (%.1f lots)\n', ...
            -delta0(1), contractName(cfg.leg1), -delta0(1)/cfg.lotSize, ...
            -delta0(2), contractName(cfg.leg2), -delta0(2)/cfg.lotSize);
        if cfg.runValidation
            validatePricers(mkt, Kput, cfg);
        end
    end

    % ---- (f) reprice the collar: long Put(Kput), short Call(Kcall) ----
    [V, parts] = collarValue(mkt, Kput, cfg);

    % ---- (g) P&L of the hedge held since yesterday, interest on cash ----
    if s > 1
        interest = cash * (1/discountFactor(data.sofr, tPrev, t) - 1);
        % [ROBUST] Same SOFR rate for borrowing and lending; a real desk pays a
        %          spread over SOFR when it borrows.
        futPnL = pos * (F - Fprev)';   % daily variation margin, credited to cash
        cash = cash + interest + futPnL;
        res.interest(s) = interest;
        res.futPnL(s)   = futPnL;
    end

    % ---- (h) rebalance: delta hedge on both legs (Task 6) ----
    delta  = collarDelta(mkt, Kput, cfg);   % dV/df_i in bbl
    target = -delta;                         % futures (bbl) that offset it
    % [ROBUST] Positions are not rounded to whole lots (1 lot = 1,000 bbl).
    %          Rounding is more realistic and adds a small tracking error.
    % [ROBUST] Rebalancing every day pays the spread on every small change in
    %          delta. A no-trade band (trade only when |target - pos| exceeds a
    %          threshold) usually saves costs at the price of a little more risk.
    % [ROBUST] Only delta is hedged; vega and gamma stay open. They are the
    %          main source of P&L when implied vols jump (spring 2020).
    %          To add a vega hedge:
    %            1) collar vega: shift both smiles up by 1 vol point (add 0.01
    %               to sm{i}.coef(end)), reprice with collarValue, difference;
    %            2) choose a liquid listed option on the leg-1 contract (e.g.
    %               strike near Kput or Kcall) and compute its Black-76 vega;
    %            3) hold -vegaCollar/vegaOption units of it, paying half its
    %               bid-ask spread on every trade;
    %            4) subtract the option position's delta from the futures
    %               target so the whole book stays delta neutral;
    %            5) the option is futures-style margined: its daily P&L is the
    %               change in its settlement price, credited to cash like a future.
    trade = target - pos;
    cost  = sum(abs(trade) .* futuresHalfSpread(data.fut, j, col, cfg));
    cash  = cash - cost;
    pos   = target;

    % ---- (i) portfolio value and daily P&L ----
    % Futures are worth zero after the daily settlement, so the portfolio is the
    % collar (marked to model) plus the cash account.
    Pi = V + cash;
    res.F(s, :)       = F;
    res.rho(s)        = rho;
    res.sigPut(s, :)  = parts.sigPut;
    res.sigCall(s, :) = parts.sigCall;
    res.P(s)          = parts.P;
    res.C(s)          = parts.C;
    res.V(s)          = V;
    res.delta(s, :)   = delta;
    res.pos(s, :)     = pos;
    res.cost(s)       = cost;
    res.cash(s)       = cash;
    res.Pi(s)         = Pi;
    res.PnL(s)        = Pi - PiPrev;

    Fprev  = F;
    tPrev  = t;
    PiPrev = Pi;
end

%% 5. Results
% [CHECK] The first P&L is the spread paid on the initial hedge (the collar is
%         worth zero at inception). It is included in the metric below; ask
%         whether the instructors count day 0.
mse         = mean(res.PnL.^2);
mseUnhedged = mean(diff([0; res.V]).^2);    % collar alone, for comparison

fprintf('\n=============== Backtest %s to %s ===============\n', ...
    datestr(res.date(1), 'dd-mmm-yyyy'), datestr(res.date(end), 'dd-mmm-yyyy'));
fprintf('Rebalancing dates:              %d\n', nT);
fprintf('Final portfolio value:          %14.2f USD\n', res.Pi(end));
fprintf('  of which collar value:        %14.2f USD\n', res.V(end));
fprintf('  of which cash:                %14.2f USD\n', res.cash(end));
fprintf('Total transaction costs:        %14.2f USD\n', sum(res.cost));
fprintf('Total interest:                 %14.2f USD\n', sum(res.interest));
fprintf('Mean squared daily P&L:         %14.4e USD^2 (RMS %.0f USD)\n', mse, sqrt(mse));
fprintf('Same metric, collar unhedged:   %14.4e USD^2 (RMS %.0f USD)\n', ...
    mseUnhedged, sqrt(mseUnhedged));

save(sprintf('results_%s.mat', cfg.caseName), 'res', 'cfg', 'sched', 'Kput', 'mse');

%% 6. Plots
if cfg.makePlots
    figure('Name', 'Portfolio value');
    plot(res.date, res.Pi/1e6, 'LineWidth', 1.5); grid on;
    datetick('x', 'mmm-yy', 'keeplimits');
    ylabel('USD million');
    title('Portfolio value: collar + futures hedge + cash');

    figure('Name', 'Squared daily P&L');
    plot(res.date, res.PnL.^2, 'LineWidth', 1); grid on;
    datetick('x', 'mmm-yy', 'keeplimits');
    ylabel('USD^2');
    title(sprintf('Squared daily P&L, mean = %.3e USD^2', mse));

    figure('Name', 'Collar and hedge');
    subplot(2, 1, 1);
    plot(res.date, res.V/1e6, 'LineWidth', 1.5); grid on;
    datetick('x', 'mmm-yy', 'keeplimits');
    ylabel('USD million');
    title('Collar value, market maker side (long put, short call)');
    subplot(2, 1, 2);
    plot(res.date, res.pos/cfg.lotSize, 'LineWidth', 1.5); grid on;
    datetick('x', 'mmm-yy', 'keeplimits');
    ylabel('lots (1,000 bbl)');
    legend(contractName(cfg.leg1), contractName(cfg.leg2), 'Location', 'best');
    title('Futures hedge positions');
end
