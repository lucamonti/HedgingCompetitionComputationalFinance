function s = contractName(code)
%CONTRACTNAME Contract month yyyymm -> short name, e.g. 202104 -> 'Apr21'.
mons = {'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'};
s = sprintf('%s%02d', mons{mod(code, 100)}, mod(floor(code/100), 100));
end
