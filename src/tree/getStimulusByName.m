function stimulus = getStimulusByName(epoch, deviceName)
% GETSTIMULUSBYNAME Get stimulus data from epoch by device name
%
% Usage:
%   stimulus = getStimulusByName(epoch, deviceName)
%
% Inputs:
%   epoch - Epoch struct
%   deviceName - Device name string (e.g., 'Stage', 'LED')
%
% Outputs:
%   stimulus - Stimulus struct with fields:
%              .device_name, .data, .sample_rate, etc.
%              Returns [] if not found
%
% Description:
%   Searches the epoch's stimuli array for a stimulus with the
%   specified device name. This is the MATLAB equivalent of
%   Java's epoch.stimuli(name).
%
% Examples:
%   stim = getStimulusByName(epoch, 'LED');
%   if ~isempty(stim)
%       stimTrace = stim.data;
%   end
%
% See also: getResponseByName, getStreamNames

    stimulus = [];

    if isempty(epoch) || ~isfield(epoch, 'stimuli')
        return;
    end

    stimuli = epoch.stimuli;

    % Handle array of structs
    if isstruct(stimuli)
        for i = 1:length(stimuli)
            stim = stimuli(i);
            if isfield(stim, 'device_name') && strcmp(stim.device_name, deviceName)
                stimulus = stim;
                return;
            end
        end
    end
end
