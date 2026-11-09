function [V, parts] = collarValue(mkt, Kput, cfg)
%COLLARVALUE Value in USD of the market maker's position on the full
% notional: long Put(Kput), short Call(Kcall). Each option reads its own vols
% off the smiles at its own strike.
[P, sigP] = basketOptionSmile(Kput, false, mkt);
[C, sigC] = basketOptionSmile(cfg.Kcall, true, mkt);
V = cfg.notional * (P - C);
parts.P = P;
parts.C = C;
parts.sigPut  = sigP;
parts.sigCall = sigC;
end
