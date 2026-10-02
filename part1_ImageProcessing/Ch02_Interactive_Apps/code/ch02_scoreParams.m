function [score, detail] = ch02_scoreParams(ds, expected, varargin)
%CH02_SCOREPARAMS 評估一組參數在整個資料集上的正確率。
%
%   SCORE = CH02_SCOREPARAMS(DS, EXPECTED) 對 imageDatastore DS 中的每張
%   影像執行 ch02_findChips，回傳計數等於 EXPECTED 的影像比例（0–1）。
%
%   [SCORE, DETAIL] = CH02_SCOREPARAMS(___) 另外回傳每張影像的明細 table，
%   含計數、誤差與是否正確。
%
%   CH02_SCOREPARAMS(DS, EXPECTED, ...) 接受並轉傳 ch02_findChips 的所有
%   名稱-值引數。
%
%   這是第 02 章練習 4 的解答，也是通往第 18 章「超參數掃描」的第一步：
%   有了一個能回傳單一分數的函式，就能用迴圈或 Experiment Manager 自動
%   搜尋最佳參數，不必再手動試。
%
%   範例：
%     ds = imageDatastore("測試資料夾");
%
%     % 單一組參數
%     s = ch02_scoreParams(ds, 6)
%
%     % 掃描明度門檻
%     vals = 0.1:0.05:0.5;
%     scores = arrayfun(@(v) ch02_scoreParams(ds, 6, MinValue=v), vals);
%     plot(vals, scores); xlabel("MinValue"); ylabel("正確率")
%
%   另見 CH02_FINDCHIPS, CH02_BATCHCOUNT.

arguments
    ds       (1,1) matlab.io.datastore.ImageDatastore
    expected (1,1) double {mustBeNonnegative, mustBeInteger}
end
arguments (Repeating)
    varargin
end

reset(ds);
n     = numel(ds.Files);
names = strings(n,1);
count = nan(n,1);

for k = 1:n
    [I, info] = read(ds);
    [~, nm]   = fileparts(info.Filename);
    names(k)  = string(nm);
    try
        count(k) = height(ch02_findChips(I, varargin{:}));
    catch
        count(k) = NaN;   % 失敗視為不正確，但不中斷整批
    end
end

correct = count == expected;
score   = mean(correct);

detail = table(names, count, count - expected, correct, ...
    VariableNames=["Name" "Count" "Error" "Correct"]);
end
