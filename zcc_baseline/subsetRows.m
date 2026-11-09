function s = subsetRows(s, idx)
%SUBSETROWS Apply the same row selection to every field of a struct of columns.
fn = fieldnames(s);
for k = 1:numel(fn)
    s.(fn{k}) = s.(fn{k})(idx);
end
end
