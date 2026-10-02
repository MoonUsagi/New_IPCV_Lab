function [masks, boxes, scores, info] = ch17_groundedSAM(I, prompt, options)
%CH17_GROUNDEDSAM 文字 -> 框 -> 遮罩：兩個基礎模型串起來做像素級自動標註。
%
%   [MASKS, BOXES, SCORES, INFO] = CH17_GROUNDEDSAM(I, PROMPT) 先用
%   Grounding DINO 依文字提示找出框，再用 SAM 把每個框轉成遮罩。
%
%   回傳 MASKS（H-by-W-by-K logical）、BOXES、SCORES 與 INFO（計時與計數）。
%
%   名稱-值引數：
%     ClassName - 類別名稱（預設 "object"）
%     Threshold - Grounding DINO 的分數下限（預設 0.35）
%     MaxObjects - 最多處理幾個框（預設 10）
%
%   **為什麼要串起來**
%
%   兩個模型各自缺一半：
%
%     Grounding DINO  懂文字，但只輸出**矩形框**
%     SAM             輸出精確遮罩，但**不懂你要什麼**
%                     （它只能回應座標提示，不能回應 "car"）
%
%   串起來就得到「用一句英文產生像素級標註」。
%   這是第 17 章能存在的原因之一：**標註成本以前是專案的主要成本。**
%
%   **實作上的三個細節**
%
%   ① `extractEmbeddings` 對整張影像只要算**一次**，
%      然後所有框共用。K 個框不需要跑 K 次骨幹網路——
%      這是 SAM 架構刻意的設計（重的編碼器跑一次，輕的解碼器跑 K 次）。
%
%   ② `segmentObjectsFromEmbeddings` 的 `BoundingBox` 一次只吃
%      **一個 1x4 向量**，所以框要自己迴圈。傳整個 Kx4 矩陣會報錯。
%
%   ③ 分數門檻要設。Grounding DINO 的低分框很多
%      （見 CH17_PROMPTSWEEP：提示詞 "car" 在 20 張圖上給了 65 個框，
%      其中 43 個是誤框），每個誤框都會讓 SAM 多算一次遮罩。
%      **這裡的門檻是效能與 recall 的取捨，不是品質開關。**
%
%   另見 CH17_AUTOLABEL, SEGMENTANYTHINGMODEL, IMSEGSAM.

arguments
    I {mustBeNumeric, mustBeNonempty}
    prompt (1,1) string {mustBeNonzeroLengthText}
    options.ClassName  (1,1) string = "object"
    options.Threshold  (1,1) double {mustBeNonnegative} = 0.35
    options.MaxObjects (1,1) double {mustBePositive, mustBeInteger} = 10
end

% --- 第一步：文字 -> 框 ----------------------------------------------
detector = groundingDinoObjectDetector("swin-tiny", ...
    ClassNames=options.ClassName, ClassDescriptions=prompt);

tDet = tic;
[boxes, scores] = detect(detector, I);
secDetect = toc(tDet);

if ~isempty(boxes)
    keep = scores >= options.Threshold;
    boxes = boxes(keep,:);
    scores = scores(keep);
end
if size(boxes,1) > options.MaxObjects
    [scores, ord] = sort(scores, "descend");
    boxes = boxes(ord,:);
    boxes = boxes(1:options.MaxObjects,:);
    scores = scores(1:options.MaxObjects);
end

nBox = size(boxes,1);
if nBox == 0
    masks = false(size(I,1), size(I,2), 0);
    info = struct("NumBoxes", 0, "SecDetect", secDetect, ...
        "SecEmbed", 0, "SecMasks", 0);
    warning("ch17_groundedSAM:noDetections", ...
        "提示詞「%s」在分數門檻 %.2f 之下沒有任何框。" + ...
        "先降門檻或換提示詞——**不要直接下結論說影像裡沒有目標**。", ...
        prompt, options.Threshold);
    return
end

% --- 第二步：框 -> 遮罩 ----------------------------------------------
% **先把 Grounding DINO 釋放掉再載入 SAM。**
% 兩個基礎模型同時留在顯示記憶體裡，在 4 GB 的卡上會把後者
% 逼進退化路徑（實測慢 6 倍以上，而且不會有任何警告）。
% 這裡已經用不到偵測器了，所以清掉它。
clear detector

sam = segmentAnythingModel;

% 重的編碼器只跑一次
tEmb = tic;
embeddings = extractEmbeddings(sam, I);
secEmbed = toc(tEmb);

masks = false(size(I,1), size(I,2), nBox);
tMask = tic;
for k = 1:nBox
    % BoundingBox 一次只吃一個 1x4 向量
    m = segmentObjectsFromEmbeddings(sam, embeddings, size(I), ...
        BoundingBox=boxes(k,:));
    masks(:,:,k) = m;
end
secMasks = toc(tMask);

info = struct( ...
    "NumBoxes",  nBox, ...
    "SecDetect", secDetect, ...
    "SecEmbed",  secEmbed, ...
    "SecMasks",  secMasks, ...
    "SecPerMask", secMasks / nBox);
end
