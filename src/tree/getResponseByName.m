function response = getResponseByName(epoch, deviceName)
% GETRESPONSEBYNAME Get response data from epoch by device name
%
% Usage:
%   response = getResponseByName(epoch, deviceName)
%
% Inputs:
%   epoch - Epoch struct
%   deviceName - Device name string (e.g., 'Amp1')
%
% Outputs:
%   response - Response struct with fields:
%              .device_name, .data, .spike_times, .sample_rate, etc.
%              Returns [] if not found
%
% Description:
%   Searches the epoch's responses array for a response with the
%   specified device name. This is the MATLAB equivalent of
%   Java's epoch.responses(name).
%
% Examples:
%   resp = getResponseByName(epoch, 'Amp1');
%   if ~isempty(resp)
%       voltage = resp.data;
%       spikes = resp.spike_times;
%   end
%
% See also: getStimulusByName, getStreamNames, getResponseData

    response = [];

    if isempty(epoch) || ~isfield(epoch, 'responses')
        return;
    end

    responses = epoch.responses;

    % Handle array of structs
    if isstruct(responses)
        for i = 1:length(responses)
            resp = responses(i);
            if isfield(resp, 'device_name') && strcmp(resp.device_name, deviceName)
                response = resp;
                return;
            end
        end
    end
end
