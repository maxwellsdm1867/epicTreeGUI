function [data, sampleRate, spikeTimes] = getResponseData(epoch, deviceName)
% GETRESPONSEDATA Get response data array from epoch
%
% Usage:
%   [data, sampleRate, spikeTimes] = getResponseData(epoch, deviceName)
%
% Inputs:
%   epoch - Epoch struct
%   deviceName - Device name string (e.g., 'Amp1')
%
% Outputs:
%   data - Response data array (voltage/current trace), [] if not found
%   sampleRate - Sample rate in Hz, [] if not found
%   spikeTimes - Spike times in ms, [] if not available
%
% Description:
%   Convenience function to extract response data directly.
%   This is the MATLAB equivalent of Java's response.data().
%
% Examples:
%   [voltage, fs, spikes] = getResponseData(epoch, 'Amp1');
%   time = (0:length(voltage)-1) / fs * 1000;  % ms
%   plot(time, voltage);
%
%   % Check for spikes
%   if ~isempty(spikes)
%       hold on;
%       plot(spikes, zeros(size(spikes)), 'r|');
%   end
%
% See also: getResponseByName, getStimulusByName

    data = [];
    sampleRate = [];
    spikeTimes = [];

    response = getResponseByName(epoch, deviceName);

    if isempty(response)
        return;
    end

    if isfield(response, 'data')
        data = response.data;
        % Ensure row vector
        if size(data, 1) > size(data, 2)
            data = data';
        end
    end

    if isfield(response, 'sample_rate')
        sampleRate = response.sample_rate;
    end

    if isfield(response, 'spike_times')
        spikeTimes = response.spike_times;
        % Ensure row vector
        if ~isempty(spikeTimes) && size(spikeTimes, 1) > size(spikeTimes, 2)
            spikeTimes = spikeTimes';
        end
    end
end
