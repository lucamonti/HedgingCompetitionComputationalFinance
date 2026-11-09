function d = addBusinessDays(d, n, holidays)
%ADDBUSINESSDAYS Move date d by n business days (n can be negative or zero).
step = sign(n);
for k = 1:abs(n)
    d = d + step;
    while ~isBusinessDay(d, holidays)
        d = d + step;
    end
end
end
