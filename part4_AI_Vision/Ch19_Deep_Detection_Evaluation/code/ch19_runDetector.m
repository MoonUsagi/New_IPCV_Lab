function [raw, info] = ch19_runDetector(detector, files, options)
%CH19_RUNDETECTOR 對一批影像跑偵測，回傳未經處理的原始結果。
%
%   [RAW, INFO] = CH19_RUNDETECTOR(DETECTOR, FILES) 對 FILES 逐張推論，
%   回傳 RAW（含 Boxes／Scores／Labels 三欄的 table，**保留偵測器
%   原本的類別名稱**）與 INFO（計時與類別統計）。
%
%   名稱-值引數：
%     Threshold - 分數下限（預設 0，不過濾）
%     Verbose   - 印出進度（預設 false）
%
%   **為什麼要「保留原本的類別名稱」**
%
%   這是本章的核心設計。很多教學會直接把偵測結果對應成
%   自己資料集的類別再評估，於是**那個對應的決定被藏起來了**。
%   第 3 節會證明：光是換一個對應方式，AP 就從 0.261 變成 0.483。
%
%   所以這個函式**只做推論、不做任何對應**，對應留給
%   CH19_CLASSMAPPING 當成一個可以掃描的變數。
%
%   **暖機**：第一次 `detect` 含模型載入（約 7 秒），
%   所以這裡先跑一張不計時。暖機後在 T550 上約
%   **0.07 秒／張**（128x228 的小圖）。
%
%   另見 CH19_CLASSMAPPING, YOLOXOBJECTDETECTOR.

arguments
    detector
    files (1,:) string {mustBeNonempty}
    options.Threshold (1,1) double {mustBeNonnegative} = 0
    options.Verbose   (1,1) logical = false
end

% 暖機：第一次呼叫含模型載入，不計時
detect(detector, imread(files(1)));

n = numel(files);
Boxes = cell(n,1); Scores = cell(n,1); Labels = cell(n,1);

t = tic;
for k = 1:n
    [b, s, l] = detect(detector, imread(files(k)));
    if options.Threshold > 0 && ~isempty(b)
        keep = s >= options.Threshold;
        b = b(keep,:); s = s(keep); l = l(keep);
    end
    Boxes{k} = b; Scores{k} = s; Labels{k} = l;
    if options.Verbose
        fprintf("  [%3d/%3d] %d 框\n", k, n, size(b,1));
    end
end
secTotal = toc(t);

raw = table(Boxes, Scores, Labels);

allLabels = vertcat(Labels{:});
if isempty(allLabels)
    counts = table(strings(0,1), zeros(0,1), VariableNames=["類別" "次數"]);
else
    u = categories(removecats(allLabels));
    c = zeros(numel(u),1);
    for k = 1:numel(u)
        c(k) = nnz(allLabels == u{k});
    end
    [c, ord] = sort(c, "descend");
    counts = table(string(u(ord)), c, VariableNames=["類別" "次數"]);
end

info = struct( ...
    "NumImages",   n, ...
    "NumBoxes",    numel(allLabels), ...
    "SecPerImage", secTotal/n, ...
    "ClassCounts", counts);
end
