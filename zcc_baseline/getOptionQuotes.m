function q = getOptionQuotes(opt, t, code)
%GETOPTIONQUOTES Quotes of the options on futures contract `code` on date t.
idx = opt.date == t & opt.code == code;
q.strike = opt.strike(idx);
q.isCall = opt.isCall(idx);
q.bid    = opt.bid(idx);
q.ask    = opt.ask(idx);
q.settle = opt.settle(idx);
end
