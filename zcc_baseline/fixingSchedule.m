function sched = fixingSchedule(cfg)
%FIXINGSCHEDULE Fixing dates and roll rule (Annex B).
%   All business days of the averaging month are fixing dates. The reference
%   price is the first-nearby contract (leg 1) up to and including the
%   second-to-last fixing day before its expiry; from the next fixing day on,
%   it is the next-nearby contract (leg 2).

y = cfg.avgYear;
m = cfg.avgMonth;
days = (datenum(y, m, 1):datenum(y, m, eomday(y, m)))';
fixDates = days(isBusinessDay(days, cfg.holidays));

futLTD1 = iceBrentExpiry(cfg.leg1, cfg.holidays);
if futLTD1 < fixDates(1) || futLTD1 > fixDates(end)
    error('fixingSchedule: the leg-1 expiry is not inside the averaging month.');
end

% [CHECK] Interpretation of "up to and including the second-to-last fixing day
%         before that contract's expiry": take the fixing days strictly before
%         the expiry date and keep leg 1 up to the k-th to last of them, with
%         k = cfg.rollFixingsBeforeExpiry (2 = second-to-last). Feb 2021 with
%         k = 2: Apr21 expires Fri 26 Feb, so Apr21 fixes 1-24 Feb (18 days)
%         and May21 fixes 25-26 Feb (2 days). See setupConfig.m for k = 3.
before   = fixDates(fixDates < futLTD1);
lastLeg1 = before(end - cfg.rollFixingsBeforeExpiry + 1);

sched.fixDates = fixDates;
sched.leg      = 1 + (fixDates > lastLeg1);   % 1 = leg 1, 2 = leg 2
sched.N        = numel(fixDates);
sched.n1       = sum(sched.leg == 1);
sched.n2       = sum(sched.leg == 2);
sched.lastLeg1 = lastLeg1;
sched.futLTD1  = futLTD1;
sched.T        = addBusinessDays(fixDates(end), cfg.payLagBD, cfg.holidays);  % payment date
end
