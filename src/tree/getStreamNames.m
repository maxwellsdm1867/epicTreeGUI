function names = getStreamNames(epochs, streamType)
% GETSTREAMNAMES Get unique response or stimulus stream names from epochs
%
% Usage:
%   names = getStreamNames(epochs, streamType)
%
% Inputs:
%   epochs - Cell array of epoch structs
%   streamType - 'responses' or 'stimuli'
%
% Outputs:
%   names - Cell array of unique stream names (device names)
%
% Description:
%   Scans all epochs to find unique response or stimulus stream names.
%   This is useful for knowing what data channels are available.
%
% Examples:
%   % Get response stream names
%   responseNames = getStreamNames(epochs, 'responses');
%   % Returns: {'Amp1', 'Amp2'}
%
%   % Get stimulus stream names
%   stimNames = getStreamNames(epochs, 'stimuli');
%   % Returns: {'Stage', 'LED'}
%
% See also: getResponseByName, getStimulusByName, getAllEpochs

    names = {};
    nameSet = containers.Map();

    if isempty(epochs)
        return;
    end

    for i = 1:length(epochs)
        epoch = epochs{i};

        if ~isfield(epoch, streamType)
            continue;
        end

        streams = epoch.(streamType);

        % Handle array of structs
        if isstruct(streams)
            for j = 1:length(streams)
                stream = streams(j);
                if isfield(stream, 'device_name') && ~isempty(stream.device_name)
                    name = stream.device_name;
                    if ~nameSet.isKey(name)
                        nameSet(name) = true;
                        names{end+1} = name;
                    end
                end
            end
        end
    end

    % Sort names for consistency
    names = sort(names);
    names = names(:);  % Column vector
end
