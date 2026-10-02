function tbl = ch17_promptSweep(files, prompts, gtBoxes, options)
%CH17_PROMPTSWEEP 掃描不同的文字提示詞，量它們對標註品質的影響。
%
%   TBL = CH17_PROMPTSWEEP(FILES, PROMPTS, GTBOXES) 對每個提示詞跑一次
%   完整的自動標註與評估，回傳一張比較表。
%
%   名稱-值引數（轉傳給 CH17_AUTOLABEL 與 CH17_EVALAUTOLABEL）：
%     ClassName    - 類別名稱（預設 "object"）
%     IoUThreshold - 命中門檻（預設 0.5）
%     Verbose      - 印出每個提示詞的進度（預設 true）
%
%   **這個函式存在的理由：提示詞是一個超參數，而且是很敏感的一個。**
%
%   實測（vehicles 均勻取樣 20 張、swin-tiny、IoU 0.5）：
%
%     提示詞                總框數  precision  recall     AP   秒/張
%     "car"                    65     33.8%   100.0%  0.873   1.82
%     "vehicle"                15     93.3%    63.6%  0.597   1.83
%     "a car on the road"      38     55.3%    95.5%  0.908   1.85
%
%   **同一個模型、同一批影像，只改英文用字，
%   precision 從 33.8% 到 93.3%、recall 從 63.6% 到 100.0%。**
%
%   而且三個指標各有各的贏家：
%
%     recall 最高    -> "car"
%     precision 最高 -> "vehicle"
%     AP 最高        -> "a car on the road"
%
%   **又一次「兩個指標給出相反排序」**（第 11、12、14、15、16 章都出現過）。
%   但這一章的旋鈕特別不直覺：**它是英文用字，不是數值參數。**
%   沒有梯度、沒有單調性、沒辦法二分搜尋。
%
%   怎麼選？看下游是誰（見 CH17_EVALAUTOLABEL 的說明）：
%   預標註給人修 -> 選 recall 最高的 "car"；
%   要直接當訓練標籤用（沒有人會看）-> 選 AP 最高的。
%
%   **不要只試一個提示詞就下結論。** 這張表要花 20 張 x 3 個提示詞
%   x 1.8 秒 ≈ 110 秒——比事後發現標註品質不對再重跑便宜得多。
%
%   另見 CH17_AUTOLABEL, CH17_EVALAUTOLABEL.

arguments
    files   (1,:) string {mustBeNonempty}
    prompts (1,:) string {mustBeNonempty}
    gtBoxes cell
    options.ClassName    (1,1) string = "object"
    options.IoUThreshold (1,1) double {mustBeInRange(options.IoUThreshold,0,1)} = 0.5
    options.Verbose      (1,1) logical = true
end

nP = numel(prompts);
promptCol = strings(nP,1);
nBox = zeros(nP,1); prec = zeros(nP,1); rec = zeros(nP,1);
ap = zeros(nP,1); sec = zeros(nP,1);
toDelete = zeros(nP,1); toDraw = zeros(nP,1); meanIoU = zeros(nP,1);

for k = 1:nP
    if options.Verbose
        fprintf("  提示詞 %d/%d：""%s"" ...\n", k, nP, prompts(k));
    end

    [det, s] = ch17_autoLabel(files, prompts(k), ClassName=options.ClassName);

    % 漏標的警告在掃描時會重複出現，這裡暫時關掉；
    % 表格本身就會把 NumToDraw 呈現出來。
    ws = warning("off", "ch17_evalAutoLabel:missedObjects");
    r = ch17_evalAutoLabel(det, gtBoxes, ClassName=options.ClassName, ...
        IoUThreshold=options.IoUThreshold);
    warning(ws);

    promptCol(k) = prompts(k);
    nBox(k) = r.NumBoxes;  prec(k) = r.Precision;  rec(k) = r.Recall;
    ap(k) = r.AP;          sec(k) = s;
    toDelete(k) = r.NumToDelete;  toDraw(k) = r.NumToDraw;
    meanIoU(k) = r.MeanIoU;
end

tbl = table(promptCol, nBox, prec, rec, ap, toDelete, toDraw, meanIoU, sec, ...
    VariableNames=["提示詞" "總框數" "precision" "recall" "AP" ...
                   "要刪的誤框" "要畫的漏標" "命中平均IoU" "秒每張"]);

% 三個指標的贏家是不是同一個提示詞？
[~, iP] = max(prec);  [~, iR] = max(rec);  [~, iA] = max(ap);
if numel(unique([iP iR iA])) > 1
    fprintf("\n**precision／recall／AP 的最佳提示詞不是同一個**" + ...
        "（分別是 ""%s""／""%s""／""%s""）。\n", ...
        promptCol(iP), promptCol(iR), promptCol(iA));
    fprintf("要選哪一個，取決於這批標註的下游是人還是模型。\n");
end
end
