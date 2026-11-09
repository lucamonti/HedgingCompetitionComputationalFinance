function tf = isBusinessDay(d, holidays)
%ISBUSINESSDAY True for Monday-Friday dates that are not in the holiday list.
wd = weekday(d);                       % 1 = Sunday, 7 = Saturday
tf = wd ~= 1 & wd ~= 7 & ~ismember(d, holidays);
end
