%% Inspect MAT File Structure
% Quick inspection of the test data file

clear all; clc;

file_path = '/Users/maxwellsdm/Documents/epicTreeTest/analysis/2025-12-02_F.mat';

fprintf('=== Inspecting MAT File ===\n');
fprintf('File: %s\n\n', file_path);

try
    % Load and display contents
    data = load(file_path);
    
    fprintf('Top-level fields:\n');
    fields = fieldnames(data);
    for i = 1:length(fields)
        fname = fields{i};
        fval = data.(fname);
        fprintf('  %s: ', fname);
        
        if isstruct(fval)
            fprintf('[struct with %d fields]\n', length(fieldnames(fval)));
            if length(fieldnames(fval)) < 10
                subfields = fieldnames(fval);
                for j = 1:length(subfields)
                    fprintf('    - %s\n', subfields{j});
                end
            end
        elseif iscell(fval)
            fprintf('[cell array %s]\n', mat2str(size(fval)));
        elseif isnumeric(fval) || islogical(fval)
            fprintf('[%s %s]\n', class(fval), mat2str(size(fval)));
        elseif ischar(fval)
            fprintf('[string]: "%s"\n', fval);
        else
            fprintf('[%s]\n', class(fval));
        end
    end
    
    % Check for standard format fields
    fprintf('\n=== Format Check ===\n');
    if isfield(data, 'format_version')
        fprintf('✓ Has format_version: %s\n', data.format_version);
    else
        fprintf('✗ Missing format_version\n');
    end
    
    if isfield(data, 'metadata')
        fprintf('✓ Has metadata\n');
    else
        fprintf('✗ Missing metadata\n');
    end
    
    if isfield(data, 'experiments')
        fprintf('✓ Has experiments\n');
        if isstruct(data.experiments)
            fprintf('  Number of experiments: %d\n', length(data.experiments));
        end
    else
        fprintf('✗ Missing experiments\n');
    end
    
catch ME
    fprintf('ERROR: %s\n', ME.message);
    fprintf('\nStack trace:\n');
    for i = 1:length(ME.stack)
        fprintf('  %s (line %d)\n', ME.stack(i).name, ME.stack(i).line);
    end
end
