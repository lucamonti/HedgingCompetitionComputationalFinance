function [futLTD, optLTD] = iceBrentExpiry(code, holidays)
%ICEBRENTEXPIRY Last trading days of an ICE Brent futures contract and of
% the options written on it.
%   code: contract month as yyyymm (e.g. 202104 = Apr21)
%   Futures: last business day of the second month before the contract month
%            (Apr21 -> last business day of Feb 2021 = 26 Feb 2021).
%   Options: three business days before the futures' last trading day.
% [CHECK] Rule in force for contracts from Mar16 on. Verify against the
%         official ICE expiry calendar or the expiry dates in the dataset.

y = floor(code/100);
m = mod(code, 100) - 2;
if m <= 0
    m = m + 12;
    y = y - 1;
end
futLTD = datenum(y, m, eomday(y, m));
while ~isBusinessDay(futLTD, holidays)
    futLTD = futLTD - 1;
end
optLTD = addBusinessDays(futLTD, -3, holidays);
end
