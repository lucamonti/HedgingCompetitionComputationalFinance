function cfg = setupConfig(caseName)
%SETUPCONFIG All user settings of the project in one place.
%   cfg = setupConfig('train')  collar averaging over Feb 2021 (legs Apr21, May21)
%   cfg = setupConfig('test')   collar averaging over Oct 2022 (legs Dec22, Jan23)
%
% Dates are MATLAB datenums. Futures contracts are identified by their
% contract month as yyyymm (e.g. 202104 = ICE Brent Apr21).

cfg.caseName = lower(caseName);

%% Term sheet (Annex A)
cfg.notional = 1e6;     % bbl
cfg.Kcall    = 78;      % USD/bbl, fixed
cfg.lotSize  = 1000;    % bbl per ICE Brent futures / options contract

switch cfg.caseName
    case 'train'
        cfg.tStart   = datenum(2020, 1, 6);    % emission date = first rebalancing date
        cfg.tEnd     = datenum(2021, 2, 28);   % end of the in-sample backtest
        cfg.avgYear  = 2021;                   % averaging month: February 2021
        cfg.avgMonth = 2;
        cfg.leg1     = 202104;                 % Apr21 (first nearby during Feb 2021)
        cfg.leg2     = 202105;                 % May21 (after the roll)
        cfg.dataFiles = {'full_df_train.parquet'};
    case 'test'
        % [CHECK] Inception of the out-of-sample collar assumed to be the first
        %         day of the test set (6 Apr 2021). Confirm with the instructors.
        cfg.tStart   = datenum(2021, 4, 6);
        cfg.tEnd     = datenum(2022, 10, 31);  % metric computed up to end of October
        cfg.avgYear  = 2022;                   % averaging month: October 2022
        cfg.avgMonth = 10;
        cfg.leg1     = 202212;                 % Dec22
        cfg.leg2     = 202301;                 % Jan23
        % [ADAPT] name of the test file once it is released. The training file
        %         is loaded too, so the correlation has history at inception.
        cfg.dataFiles = {'full_df_train.parquet', 'full_df_test.parquet'};
    otherwise
        error('setupConfig: unknown case "%s" (use ''train'' or ''test'').', caseName);
end

%% Calendar
% Weekdays on which ICE Futures Europe is closed. Only used to build the
% fixing dates and the expiry dates; the backtest runs on the dates in the data.
% [CHECK] against the official ICE holiday calendar.
cfg.holidays = datenum([2020 4 10; 2020 12 25; 2021 1 1; 2021 4 2; 2022 4 15]);

%% Roll rule (Annex B)
% Leg 1 fixes up to and including the k-th to last fixing day strictly before
% its futures expiry. k = 2 is the literal reading of "second-to-last".
% [CHECK] With k = 2 the last Apr21 fixing is 24 Feb 2021, but the dataset has
%         no Apr21 settlement after 23 Feb 2021 (its rows stop when the Apr21
%         options expire). main.m then uses the 23 Feb settlement and warns.
%         k = 3 makes the last leg-1 fixing coincide with the options' expiry
%         (23 Feb 2021, 26 Oct 2022), where the data ends. Ask the instructors.
cfg.rollFixingsBeforeExpiry = 2;

%% Payment date of the collar
% [CHECK] The term sheet does not say when the payoff is paid.
%         Baseline: on the last fixing date (lag = 0 business days).
cfg.payLagBD = 0;

%% Option quotes: liquidity filter and implied vols (Task 2)
cfg.minMid        = 0.01;     % USD/bbl: drop premiums below 1 tick
cfg.maxRelSpread  = 0.50;     % drop quotes with (ask - bid)/mid above 50%
cfg.minTauDays    = 5;        % drop options with fewer than 5 days to expiry
cfg.otmOnly       = true;     % keep OTM calls (K >= F) and OTM puts (K < F)
cfg.ivBounds      = [0.01 3]; % admissible implied vols (bisection bracket)
cfg.minStrikesFit = 3;        % fewer distinct strikes -> flat smile at their mean
% [ROBUST] These thresholds are round numbers, not tuned. Look at the
%          distribution of spreads and premiums in the data and justify them
%          in the report (e.g. plot relative spread against moneyness). If the
%          data has volume or open interest, filtering on them is more meaningful.

%% Correlation (Task 3)
cfg.corrWindow = 60;    % rolling window in trading days (~3 months)
cfg.corrMinObs = 20;    % with fewer valid returns, use the prior below
cfg.rhoPrior   = 0.99;  % the training data starts on the emission date, so at
                        % t0 there is no history; adjacent Brent months are
                        % almost perfectly correlated, 0.99 is a conventional prior
% [ROBUST] See estimateRho.m for alternatives (EWMA, shrinkage to the prior).

%% Hedging (Tasks 6-7)
cfg.futHalfSpread = 0.03;   % USD/bbl, used on days without a futures bid/ask.
                            % The dataset has futures bid/ask only until
                            % 1 Jun 2020; for Apr21/May21 the spread is
                            % 0.06 at the median and 0.12 at most, so half
                            % of 0.06 is used for the other days.
% [ROBUST] A constant spread ignores that liquidity changes over time; the
%          spread in March-April 2020 was wider than in quiet months.
cfg.bumpRel = 1e-4;         % relative bump for the finite-difference deltas

%% Monte Carlo (only used to validate the closed-form pricer)
cfg.mcPaths = 1e6;
cfg.mcSeed  = 42;

%% Run options
cfg.useSyntheticData = false;   % true: run everything on simulated data
cfg.runValidation    = true;    % pricer checks at inception (Note, Sec. 5.4, 6.7)
cfg.makePlots        = true;
cfg.dataDir          = 'data';  % [ADAPT] folder containing the parquet file(s)
end
