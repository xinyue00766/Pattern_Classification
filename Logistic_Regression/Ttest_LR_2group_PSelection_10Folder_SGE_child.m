function Ttest_LR_2group_PSelection_10Folder_SGE_child(SubjectsData_Path, i, P_Value_Range, Pre_Method, ResultantFolder)
%
% SubjectData_Path:
%           path of .mat file containing a m*n matrix
%           m is the number of subjects
%           n is the number of features
%
% Subject_Label:
%           array of 1 or -1
%
% i:
%           the ith folder
%
% P_Value:
%           threshold to delete non-important features
%
% Pre_Method:
%           'Scale' or 'Normalzie'
%
% ResultantFolder:
%           the path of folder storing resultant files
%

if ~exist(ResultantFolder, 'dir')
    mkdir(ResultantFolder);
end
load(SubjectsData_Path);
    
t=weka.classifiers.functions.Logistic();

All_Training = Subjects_Data.Training_all_data; 
Label = Subjects_Data.Training_all_Label;
test_data = Subjects_Data.test_data;
test_label = Subjects_Data.test_label;

for j = 1:length(P_Value_Range)
    for k = 1:20
        ACC_10Folder_I(k) = Ttest_LR_2group_10Folder_ACC(All_Training, Label, P_Value_Range(j), Pre_Method);
    end
    Accuracy(j) = mean(ACC_10Folder_I);
end
% P_Value_BestSet = P_Value_Range(find(Accuracy == max(Accuracy)));
% P_Value_Final = P_Value_BestSet(1);
Accuracy = roundn(Accuracy, -4);
ACC_Sum_3Feature(1) = Accuracy(1) + Accuracy(1) + Accuracy(2);
for j = 2:length(P_Value_Range) - 1
    ACC_Sum_3Feature(j) = Accuracy(j-1) + Accuracy(j) + Accuracy(j+1);
end
ACC_Sum_3Feature(length(P_Value_Range)) = Accuracy(length(P_Value_Range)-1) + Accuracy(length(P_Value_Range)) + Accuracy(length(P_Value_Range));
ACC_Sum_3Feature = roundn(ACC_Sum_3Feature, -4);
MaxIndex = find(ACC_Sum_3Feature == max(ACC_Sum_3Feature));

if length(MaxIndex) > 1
    Tmp = Accuracy(MaxIndex);
    MaxIndex2 = MaxIndex(find(Tmp == max(Tmp)));
    P_Value_Final = P_Value_Range(MaxIndex2(1));
else
    P_Value_Final = P_Value_Range(MaxIndex(1));
end

save([ResultantFolder filesep 'P_Final_' num2str(i) '.mat'], 'P_Value_Final');

% T test
[PValue RetainID] = Ranking_Ttest(All_Training, Label, P_Value_Final);
All_Training_New = All_Training(:, RetainID);
save([ResultantFolder filesep 'RetainID_' num2str(i) '.mat'], 'RetainID');

if strcmp(Pre_Method, 'Normalize')
    % Normalizing
    MeanValue = mean(All_Training_New);
    StandardDeviation = std(All_Training_New);
    [rows, columns_quantity] = size(All_Training_New);
    for j = 1:columns_quantity
        if StandardDeviation(j)
            All_Training_New(:, j) = (All_Training_New(:, j) - MeanValue(j)) / StandardDeviation(j);
        end
    end
elseif strcmp(Pre_Method, 'Scale')
    % Scaling to [0 1]
    MinValue = min(All_Training_New);
    MaxValue = max(All_Training_New);
    [rows, columns_quantity] = size(All_Training_New);
    for j = 1:columns_quantity
        All_Training_New(:, j) = (All_Training_New(:, j) - MinValue(j)) / (MaxValue(j) - MinValue(j));
    end
end

% SVM classification
Label = reshape(Label, length(Label), 1);
All_Training_New = double(All_Training_New);

X_Y = data(All_Training_New, Label);
cat = wekaCategoricalData(X_Y);
t.buildClassifier(cat);

% Ttest
test_data_New = test_data(:, RetainID);
% Normalizing
if strcmp(Pre_Method, 'Normalize')
    % Normalizing
    MeanValue_New = repmat(MeanValue, length(test_label), 1);
    StandardDeviation_New = repmat(StandardDeviation, length(test_label), 1);
    test_data_New = (test_data_New - MeanValue_New) ./ StandardDeviation_New;
elseif strcmp(Pre_Method, 'Scale')
    % Scale
    MaxValue_New = repmat(MaxValue, length(test_label), 1);
    MinValue_New = repmat(MinValue, length(test_label), 1);
    test_data_New = (test_data_New - MinValue_New) ./ (MaxValue_New - MinValue_New);
end

% predicts
test_data_New = double(test_data_New);
X_Y = data(test_data_New, test_label);
dw = wekaCategoricalData(X_Y);
for j = 1:length(test_label)
    predicted_label(j) = t.classifyInstance(dw.instance(j - 1));
    decision_value(j) = [1 test_data_New(j, :)] * t.coefficients;
end

save([ResultantFolder filesep 'predicted_labels_' num2str(i) '.mat'], 'predicted_label');
save([ResultantFolder filesep 'decision_values_' num2str(i) '.mat'], 'decision_value');

% For averaging w
Logistic_Coefficients = t.coefficients;
w = Logistic_Coefficients(2:end)';
save([ResultantFolder filesep 'w_' num2str(i) '.mat'], 'w');


