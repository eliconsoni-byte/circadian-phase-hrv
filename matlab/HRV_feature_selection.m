%% HRV feature selection
% To make the model more efficient, more interpretable, and less prone to overfitting, it was
% decided to reduce the number of HRV feature selected for the analysis, eliminating redundant and
% non-informative features.
%% STEP 0: SETUP
clear; clc;

% Set subject and file
subject_id = 2;  
data_file = sprintf('subject_%d_melatonin_all.csv', subject_id);

%% Step 1: Data Loading
% After loading the data, the 51 columns corresponding to the HRV features to analized were saved
% into the variable feature_columns.
%% STEP 1: LOAD DATA
T = readtable(data_file);

% Define non-feature columns
non_features = {'Date','Start','End','MidTime','Cortisol','Melatonin'};
feature_columns = setdiff(T.Properties.VariableNames, non_features);
X = T{:, feature_columns};
feature_names = feature_columns;

%% Step 2: Spearman Correlation
% It was computed the Spearman correlation coefficient for all features. After setting the
% diagonal values equal to Null values (NaN) to avoid cross-correlation, it was computed the mean
% absolute correlation.
%% STEP 2: COMPUTE SPEARMAN CORRELATION
[R_feat, ~] = corr(X, 'type', 'Spearman');

% Remove diagonal and compute average abs correlation
R_feat(logical(eye(size(R_feat)))) = NaN;
mean_abs_corr = mean(abs(R_feat), 2, 'omitnan');



for i = 1:length(feature_names)
    fprintf("%2d. %-30s |   %6.3f\n ", ...
        i, feature_names{i}, mean_abs_corr(i));
end
% Filter features with NaN (i.e., constant features or no correlation)
valid_idx = ~isnan(mean_abs_corr);
X_filtered = X(:, valid_idx);
feature_names_filtered = feature_names(valid_idx);
R_filtered = R_feat(valid_idx, valid_idx);

fprintf("%d features retained after filtering:\n", length(feature_names_filtered));
for i = 1:length(feature_names_filtered)
    fprintf("%2d. %-30s\n ", ...
        i, feature_names_filtered{i});
end

%% Step 3: Clustering
% Similar features are clustered to facilitate visualization.
% Use 1 - |rho| as distance metric
D = 1 - abs(R_filtered);
D(1:size(D,1)+1:end) = 0;  % Ensure diagonal is zero

Y = squareform(D);         % Convert to condensed form for linkage
Z = linkage(Y, 'average'); % Hierarchical clustering
leafOrder = optimalleaforder(Z, Y);  % Optimal leaf reordering

% Reorder matrix and names
R_clustered = R_filtered(leafOrder, leafOrder);
feature_names_clustered = feature_names_filtered(leafOrder);

% Restore correct diagonal values
R_clustered(1:size(R_clustered,1)+1:end) = 1;

%% Step 4: Correlation Heatmap
figure;
h = heatmap(feature_names_clustered, feature_names_clustered, R_clustered, ...
    'Colormap', parula, ...
    'ColorLimits', [-1, 1], ...
    'CellLabelFormat','%.2f');

title(sprintf('Clustered Correlation Heatmap (no entropy) - Subject %d', subject_id));
xlabel('HRV Features'); ylabel('HRV Features');
h.XDisplayLabels = strrep(h.XDisplayLabels, '_', '\_');
h.FontSize = 10;

%% Step 5: Definition of highly correlated groups
% Along with the visual analysis, the groups of highly correlated features were defined.
% Define highly correlated threshold
threshold = 0.7;

% Initialize groups
num_features = size(R_filtered, 1);
groups = {};
group_ids = zeros(num_features, 1);
group_counter = 1;

for i = 1:num_features
    if group_ids(i) == 0
        correlated_idx = find(abs(R_filtered(i, :)) > threshold);
        % Check if any of these are already assigned
        unassigned_idx = correlated_idx(group_ids(correlated_idx) == 0);

        if ~isempty(unassigned_idx)
            groups{group_counter} = unassigned_idx;
            group_ids(unassigned_idx) = group_counter;
            group_counter = group_counter + 1;
        end
    end
end


% Display groups of highly correlated features
fprintf('\nHighly Correlated Feature Groups (|rho| > 0.7):\n');
for g = 1:length(groups)
    idx_group = groups{g};
    if length(idx_group) > 1  % Only show groups with more than 1 feature
        fprintf('Group %d:\n', g);
        for i = 1:length(idx_group)
            fprintf('   - %s\n', feature_names_filtered{idx_group(i)});
        end
        fprintf('\n');
    end
end

%% Step 6: Cortisol and Melatonin correlation
% To select among the highly correlated groups the features to mantain in the analysis, the
% correlation coefficients between each HRV feature and Cortisol and Melatonin values were
% computed.
% Extract cortisol and melatonin
cortisol = T.Cortisol;
melatonin = T.Melatonin;
fprintf('\nCorrelation of Grouped Features with Cortisol and Melatonin:\n');
 for g = 1:length(groups)
    idx_group = groups{g};
    fprintf('\nGroup %d:\n', g);
    for i = 1:length(idx_group)
        feat_idx = idx_group(i);
        feature_values = X_filtered(:, feat_idx);
        feat_name = feature_names_filtered{feat_idx};
        rho_cort = corr(feature_values, T.Cortisol, 'type', 'Spearman', 'rows', 'complete');
        rho_mel = corr(feature_values, T.Melatonin, 'type', 'Spearman', 'rows', 'complete');
        fprintf('  %-30s  |  rho(Cortisol) = %+6.3f  |  rho(Melatonin) = %+6.3f\n', ...
                feat_name, rho_cort, rho_mel);
    end
 end

%% Step 7: Feature Selection
% Based on the heatmap and successive analysis, different groups of similar features, highly
% correlated between them, were recognized. Among these groups only a limited number of features
% was selected in order to build a final cluster that is well representative, but not redundant.
% The selected features were chosen based on literature and on the correlation coefficients with
% Cortisol and Melatonin levels. Specifically there were chosen those features that presented the
% highest rho absolute value. The selected features are also consistent with the ones selected in
% the Castaldo studies.
% N.B.: Given that Approximate and Sample Entropy were not included in the visualization, their
% inclusion in the final dataset was based on literature.
selected_features = {
 'mean_HR', ...
 'std_HR', ...
 'min_HR', ...
 'max_HR', ...
 'RMSSD', ...
 'pNNxx', ...
 'HRV_tri_ind', ...
 'TINN', ...
 'Welch_LF_power', ...
 'Welch_HF_power', ...
 'Welch_LF_HF', ...
 'Welch_logtot_power', ...
 'AR_LF_power', ...
 'AR_HF_power', ...
 'AR_tot_power', ...
'Poincare_SD2', ...
'SD2_SD1', ...
'Approx_Entropy', ...
'Sample_Entropy'
 };

for i = 1:length(selected_features)
    idx = find(strcmp(T.Properties.VariableNames, selected_features{i}));
    if ~isempty(idx)
        fprintf("%2d. %-20s  → column %d\n", i, selected_features{i}, idx);
    else
        fprintf("%2d. %-20s  → Not found in table!\n", i, selected_features{i});
    end
end
