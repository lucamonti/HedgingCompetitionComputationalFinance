function delta = collarDelta(mkt, Kput, cfg)
%COLLARDELTA dV/df_i (in bbl) of the market maker's collar for the two legs,
% by central finite differences on the futures prices.
%
% The smiles are stored as functions of log-moneyness, so bumping f_i also
% moves the point where the vols are read (sticky moneyness, consistent with
% the Note's strike mapping). Once all fixings of a leg are known its delta is
% zero, so the hedge in the expiring contract is closed automatically.
%
% [ROBUST] The delta depends on how the smile is assumed to move with the
%          futures: sticky moneyness (here) vs sticky strike (keep the vols
%          fixed when bumping) give different hedge ratios. Comparing the two
%          on the backtest is a cheap, meaningful experiment.

delta = zeros(1, 2);
for i = 1:2
    h  = cfg.bumpRel * mkt.F(i);
    up = mkt;  up.F(i) = up.F(i) + h;
    dn = mkt;  dn.F(i) = dn.F(i) - h;
    delta(i) = (collarValue(up, Kput, cfg) - collarValue(dn, Kput, cfg)) / (2 * h);
end
end
