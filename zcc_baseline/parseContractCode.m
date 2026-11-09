function code = parseContractCode(name)
%PARSECONTRACTCODE Contract month as yyyymm from a name such as 'Apr21',
% 'APR-21', 'Apr 2021', '2021-04', '202104', or a futures month-letter code
% ending in e.g. 'J21' (F G H J K M N Q U V X Z = Jan ... Dec).
% [ADAPT] Extend this if your files use another naming convention.

s = upper(strtrim(char(name)));
mons = {'JAN','FEB','MAR','APR','MAY','JUN','JUL','AUG','SEP','OCT','NOV','DEC'};
letters = 'FGHJKMNQUVXZ';

tok = regexp(s, '(JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)[^0-9]*(\d{2,4})', ...
             'tokens', 'once');
if ~isempty(tok)
    m = find(strcmp(mons, tok{1}));
    y = str2double(tok{2});
else
    tok = regexp(s, '(\d{4})[-/ ]?(\d{2})', 'tokens', 'once');
    if ~isempty(tok)
        y = str2double(tok{1});
        m = str2double(tok{2});
    else
        tok = regexp(s, '([FGHJKMNQUVXZ])(\d{2})$', 'tokens', 'once');
        if isempty(tok)
            error('parseContractCode: cannot parse "%s".', s);
        end
        m = strfind(letters, tok{1});
        y = str2double(tok{2});
    end
end
if y < 100
    y = 2000 + y;
end
code = 100 * y + m;
end
