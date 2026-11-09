function p = black76(F, K, sigma, tau, isCall)
%BLACK76 Undiscounted Black-76 price (r = 0), vectorized (implicit expansion).
%   p = black76(F, K, sigma, tau, isCall),  isCall: true = call, false = put
%
% ICE Brent options are futures-style margined: no premium is paid at trade
% date, so there is nothing to discount (Asay, 1982). For an option whose
% premium is paid upfront, multiply by the discount factor D(t,T).

sd = sigma .* sqrt(max(tau, 0));
d1 = (log(F ./ K) + 0.5 * sd.^2) ./ sd;
d2 = d1 - sd;
call = F .* normCdf(d1) - K .* normCdf(d2);
put  = K .* normCdf(-d2) - F .* normCdf(-d1);

% zero volatility or zero time to expiry: intrinsic value
z = (sd <= 0) & true(size(call));
if any(z(:))
    callI = max(F - K, 0) + zeros(size(call));
    putI  = max(K - F, 0) + zeros(size(call));
    call(z) = callI(z);
    put(z)  = putI(z);
end

isC = logical(isCall) & true(size(call));
p = put;
p(isC) = call(isC);
end
