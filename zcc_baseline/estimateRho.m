function rho = estimateRho(fut, j, col, cfg)
%ESTIMATERHO Correlation between the daily log-returns of the two legs, on a
% rolling window ending at date index j (only past data, no look-ahead).
%
% Why log-returns: in the model rho is the correlation between the Brownian
% motions driving ln f(.,tau1) and ln f(.,tau2), i.e. between their
% log-increments. Called at every recalibration date, as Task 3 requires.

i0 = max(1, j - cfg.corrWindow);
r  = diff(log(fut.settle(i0:j, col)));
ok = all(~isnan(r), 2);
if sum(ok) < cfg.corrMinObs
    rho = cfg.rhoPrior;
    return
end
c   = corrcoef(r(ok, 1), r(ok, 2));
rho = min(max(c(1, 2), -0.999), 0.999);   % keeps the covariance matrix positive definite

% [ROBUST] Alternatives and refinements:
%   - an exponentially weighted (EWMA) estimate reacts faster to regime changes;
%   - shrinking the sample estimate towards the prior reduces noise;
%   - at the start of the sample, blend prior and sample estimate with weights
%     that depend on the number of observations, instead of switching abruptly
%     at cfg.corrMinObs (the switch makes the price jump, which is P&L);
%   - settlements of deferred contracts can be stale on quiet days, which biases
%     daily correlations; weekly returns are a cheap check.
% The price is not very sensitive to rho here, because leg 2 carries only
% n2/N of the weight: a sensitivity plot is a good point for the report.
end
