function cellArray = removeCellBelowLengthThreshold(cellArray, threshold)
% returns a cell array with all cells below a certain length removed
% in:
%   cellArray - array of cells, Nxcell
% out:
%   cellArray - array of cells with cells below a length threshold
%                      removed

% i = 1;
% while i < length(cellArray)
%     if length(cellArray{i}) < threshold
%         cellArray(i) = [];
%     else
%         i = i+1;
%     end
% end

num = 1:length(cellArray);
A = cellfun('length',cellArray);
smaller = A < threshold;

remove = smaller.*num';
remove = remove(remove > 0);

cellArray(remove) = [];


end