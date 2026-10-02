function [detResults, secPerImage] = ch17_autoLabel(files, prompt, options)
%CH17_AUTOLABEL 用 Grounding DINO 的文字提示自動標註一批影像。
%
%   [DETRESULTS, SECPERIMAGE] = CH17_AUTOLABEL(FILES, PROMPT) 對 FILES
%   （字串陣列）裡的每張影像跑一次零樣本偵測，PROMPT 是自然語言查詢
%   （例如 "car"、"a car on the road"）。
%
%   回傳 DETRESULTS（含 Boxes／Scores／Labels 三個變數的 table，
%   可直接餵給 EVALUATEOBJECTDETECTION）與每張影像的平均秒數。
%
%   名稱-值引數：
%     ClassName - 標籤名稱（預設 "object"）。這是寫進標註檔的類別名，
%                 與 PROMPT 分開：**提示詞可以換，類別名要固定**，
%                 否則下游的訓練資料會有多個名稱指同一類。
%     Backbone  - "swin-tiny"（預設）或 "swin-base"
%     Threshold - 分數下限，低於此值的框直接丟掉（預設 0，不過濾）
%     Verbose   - 印出進度（預設 false）
%
%   **API 有兩個地方會讓人卡住，我兩個都撞到了。**
%
%   **① 提示詞不是傳給 detect，是建構偵測器時就要給。**
%   直覺會想寫：
%
%     detect(detector, I, "car")        % ← 錯
%
%   第三個位置引數是 **ROI**，不是文字。這樣寫會得到
%   「Expected ROI to be one of these types: double, single, uint8...
%   Instead its type was string」——**錯誤訊息完全沒提到文字提示**，
%   看了只會以為自己的影像型別有問題。
%
%   正確寫法是把查詢放在 ClassDescriptions：
%
%     detector = groundingDinoObjectDetector("swin-tiny", ...
%         ClassNames="car", ClassDescriptions="a car on the road");
%     [bboxes, scores, labels] = detect(detector, I);
%
%   **② ClassNames 是唯讀的。** 建構之後不能改：
%
%     detector.ClassNames = "truck"   % ← 報 property is read-only
%
%   所以要換提示詞就得**重新建構一個偵測器**。
%   這也是為什麼下面的 CH17_PROMPTSWEEP 每個提示詞都重建一次。
%
%   **③ 第一次 detect 要額外約 10 秒**（載入模型權重）。
%   要量穩定速度必須先暖機再計時，否則第一筆會把平均值拉高。
%   暖機後在 T550 上約 1.8 秒／張（128x228 的小圖）。
%
%   **④ 每個偵測器吃掉約 1.7 GB 顯示記憶體，而且不會自己釋放。**
%   這是掃描提示詞時最容易踩到的效能陷阱。實測（T550，4.29 GB）：
%
%     保留前一個偵測器的參考再建下一個：
%       第 1 個   1.90 秒
%       第 2 個  11.64 秒   <- 顯示記憶體用完了
%       第 3 個  39.87 秒
%       第 4 個  54.50 秒
%
%     每個用完就 clear：
%       第 1 個   1.85 秒
%       第 2 個   1.88 秒
%       第 3 個   1.90 秒
%       第 4 個   1.93 秒   <- 完全平的
%
%   **28 倍的差距，而且沒有任何錯誤或警告。**
%   顯示記憶體不足時它會安靜地退化（換頁／回落），
%   看起來就只是「這台機器很慢」。
%
%   所以這個函式在回傳前**明確 clear 掉偵測器**。
%   在腳本裡自己建偵測器時也要記得——
%   腳本的工作區會一直持有它，直到腳本結束。
%
%   另見 CH17_PROMPTSWEEP, CH17_EVALAUTOLABEL, GROUNDINGDINOOBJECTDETECTOR.

arguments
    files  (1,:) string {mustBeNonempty}
    prompt (1,1) string {mustBeNonzeroLengthText}
    options.ClassName (1,1) string = "object"
    options.Backbone  (1,1) string {mustBeMember(options.Backbone,["swin-tiny" "swin-base"])} = "swin-tiny"
    options.Threshold (1,1) double {mustBeNonnegative} = 0
    options.Verbose   (1,1) logical = false
end

detector = groundingDinoObjectDetector(options.Backbone, ...
    ClassNames=options.ClassName, ClassDescriptions=prompt);

n = numel(files);
Boxes  = cell(n,1);
Scores = cell(n,1);
Labels = cell(n,1);

% 暖機：第一次呼叫含模型載入，不能算進平均時間
detect(detector, imread(files(1)));

t = tic;
for k = 1:n
    I = imread(files(k));
    [b, s, l] = detect(detector, I);

    if options.Threshold > 0 && ~isempty(b)
        keep = s >= options.Threshold;
        b = b(keep,:);  s = s(keep);  l = l(keep);
    end

    Boxes{k} = b;  Scores{k} = s;  Labels{k} = l;

    if options.Verbose
        fprintf("  [%3d/%3d] %-30s %d 框\n", k, n, ...
            extractAfter(files(k), max(strfind(files(k), filesep))), size(b,1));
    end
end
secPerImage = toc(t) / n;

% **明確釋放偵測器**（見上面的 ④）。不清掉的話，掃描提示詞時
% 顯示記憶體會累積，第二個之後的偵測器會慢 6–28 倍。
clear detector

detResults = table(Boxes, Scores, Labels);
end
