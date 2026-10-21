%% Melatonin Model: Train a Random Forest
clc;
clear;
close all;

%% Step 1: settling up
% - Define randomly the subjects used for the test
% - Load and combine all the datasets. Remove all the columns that are not used to create the
%   model, such as 'Date', 'PatientID', ...
% - Define two matrices: one with all the features (X); one for the binary 'result' (Y)
% - Split in training and test
% Define test subjects 
test_subjects = [2, 3];  

% Load and combine all subject data
all_data = [];
for subj = 1:10
    file = sprintf('subject_%d_melatonin_with_onset_threshold.csv', subj);
    T = readtable(file);
    T.PatientID = subj * ones(height(T), 1);  % Add subject ID
    all_data = [all_data; T];
end

% Prepare features and labels
label_col = 'Melatonin_Onset_Label';
% Cortisol (a second hormone) and the melatonin-derived threshold column must not be model inputs:
% the features are meant to be HRV descriptors only
non_features = {'Date', 'Start', 'End', 'MidTime', 'Melatonin', 'Cortisol', ...
                'Melatonin_Tertile_Threshold', label_col, 'PatientID'};

vars = all_data.Properties.VariableNames;
features = setdiff(vars, non_features);
is_numeric = varfun(@isnumeric, all_data(:, features), 'OutputFormat', 'uniform');
features_numeric = features(is_numeric);

fprintf('Number of input features: %d\n', numel(features_numeric));
X = all_data{:, features_numeric};
Y = categorical(all_data.(label_col));
subject_id = all_data.PatientID;

% Train/Test split by subject IDs
train_idx = ~ismember(subject_id, test_subjects);
test_idx  =  ismember(subject_id, test_subjects);

XTrain = X(train_idx, :);
YTrain = Y(train_idx);
XTest  = X(test_idx, :);
YTest  = Y(test_idx);

% Standardize features using training stats 
mu = mean(XTrain);
sigma = std(XTrain);
XTrain = (XTrain - mu) ./ sigma;
XTest  = (XTest - mu) ./ sigma;

%% Step 2:
% Train and test a bagged ensemble of classification trees
% Train
Model = fitcensemble(XTrain, YTrain, 'Method', 'Bag');

% Test
[YPred, score] = predict(Model, XTest);


%% Step 3:
% Compute confusion matrix and basic metrics to evaluate the model on test subjects
% Confusion Matrix
figure
confusionchart(YTest, YPred, ...
    'RowSummary','row-normalized', ...
    'ColumnSummary','column-normalized');
title('Test Confusion Matrix');
C  = confusionmat(YTest, YPred);

TP = C(2,2); FN = C(2,1);
FP = C(1,2); TN = C(1,1);
acc  = (TP + TN) / sum(C,'all');
sens = TP / (TP + FN);
spec = TN / (TN + FP);
precision = TP / (TP + FP);
F1 = 2 * (precision * sens) / (precision + sens);
fprintf('Accuracy:    %5.2f%%\n',   acc*100);
fprintf('Sensitivity: %5.2f%%\n',   sens*100);
fprintf('Specificity: %5.2f%%\n',   spec*100);
fprintf('Precision:   %5.2f%%\n',   precision*100);
fprintf('F1 Score:    %5.2f%%\n',   F1*100);

% ROC and AUC
[Xroc, Yroc, ~, AUC] = perfcurve(YTest, score(:,2), '1');  % '1' = high melatonin
figure;
plot(Xroc, Yroc, 'LineWidth', 2);
grid on;
xlabel('False Positive Rate');
ylabel('True Positive Rate');
title(sprintf('ROC Curve - AUC = %.3f', AUC));
fprintf('AUC: %.3f\n', AUC);
