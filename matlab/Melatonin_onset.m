%% Melatonin onset
clc;
clear;
close all;

%% Step 0: load melatonin data and check for 'Melatonin' column
% - To do so it is possible to implement the MATLAB function uigetfile that returns the file
%   name and the path of the specified file
[filename, pathname] = uigetfile('*.csv', 'Select the melatonin file'); % This opens a file browser so you can choose a .csv file with your data
% If you don’t pick a file and just close the dialog, stop everything.
if isequal(filename,0)
    error('No file selected.');
end
% Combine the path and filename into one string so we can open the file.
filepath = fullfile(pathname, filename);
% Read the CSV file into a table called T
T = readtable(filepath);
% - Make sure the table has a column named 'Melatonin'
% - If not, throw an error and stop
if ~ismember('Melatonin', T.Properties.VariableNames)
    error('Column "Melatonin" not found in the dataset.');
end

%% Step 1: compute tertile edges
% Get the data from the 'Melatonin' column
mel = T.Melatonin;
% Calculate the cut-off points that divide the data into three equal parts (tertiles).
% These are the 0th, 33rd, 66th, and 100th percentiles.
edges = quantile(mel, [0, 1/3, 2/3, 1]);  % T1, T2, T3 boundaries

%% Step 2: Extract middle tertile (33rd–66th percentile)
% Create a mask (a logical filter) that selects only the values 
% that are between the 33rd and 66th percentile (middle third).
middle_mask = mel > edges(2) & mel < edges(3);
% Save the middle values
middle_values = mel(middle_mask);
% Calculate the average (mean) of the middle tertile values
threshold = mean(middle_values); % This will be used as threshold
% Print the threshold
fprintf('Computed threshold from middle tertile: %.3f\n', threshold);

%% Step 3: Apply threshold to create binary labels
% Initialize a new vector (with zeros) to record the onset
onset = zeros(height(T), 1); 
% For the values of the melatonin greater than or equal to the threshold
% save 1 in the column
onset(mel >= threshold) = 1; % Onset detected
% Add two new columns to table
% This column shows the same threshold value for every row (for reference)
T.Melatonin_Tertile_Threshold = threshold * ones(height(T), 1);
% This column shows whether each value is above (1) or below (0) the threshold
T.Melatonin_Onset_Label = onset;

%% Step 4: Save updated file
% Get the original file name (without path or extension)
[~, name, ~] = fileparts(filename);
% Create a new file name for a new csv file
new_filename = [name, '_with_onset_threshold.csv'];
% Save the updated table in the CSV file
writetable(T, fullfile(pathname, new_filename));

% Print a message to know that the file was saved.
fprintf('Saved file with onset labels based on threshold: %s\n', new_filename);

%% Step 5: plot
% - It is useful to separete the cortisol values into two groups: the below threshol (yBelow)
%   and the above threshold (yAbove)
% Consider all the values in the column melatonin
yBelow = mel;
% Define above-threshold values as NaN
yBelow(mel > threshold) = NaN;

yAbove = mel;
% Define  below-threshold values  as NaN
yAbove(mel < threshold) = NaN;

% Open a new figure
figure
hold on
% Plot the below-threshold values in blue
plot(yBelow, '-b', 'LineWidth', 3);
% Plot the above-threshold values in red
plot(yAbove, '-r', 'LineWidth', 3);
% Draw a horizontal dashed black line showing the threshold value
yline(threshold, '--k', 'Threshold', 'LineWidth', 2);
xlabel('Sample Index');
ylabel('Melatonin [nmol/L]');
title('Subject: Melatonin & Threshold');
hold off

