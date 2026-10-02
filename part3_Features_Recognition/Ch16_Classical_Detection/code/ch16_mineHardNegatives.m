function hardNegatives = ch16_mineHardNegatives(I, gtBoxes, model, winSize, options)
%CH16_MINEHARDNEGATIVES 硬負樣本挖掘：收集偵測器誤判的視窗。
%
%   HARDNEGATIVES = CH16_MINEHARDNEGATIVES(I, GTBOXES, MODEL, WINSIZE)
%   在影像上滑動視窗，把**被判成正類別但實際不是目標**的 patch 收集起來，
%   回傳 H×W×N 的堆疊，可直接加入訓練集當新的負樣本。
%
%   名稱-值引數：
%     Stride         步長，預設 8
%     CellSize       HOG 的 CellSize，預設 [8 8]
%     MaxSamples     最多收集幾個，預設 400
%     PositiveClass  正類別名稱，預設 "circle"
%     IoUThreshold   與 GT 的 IoU 超過此值就不算誤判，預設 0.5
%
%   為什麼這是**必要**步驟而不是選配
%   --------------------------------
%   第 16 章第 6–7 節實測（4 個真實目標）：
%
%     輪次      訓練樣本   偵測框   precision   recall
%     第 1 輪      450      509       0.8%     100.0%
%     第 2 輪      850        4     100.0%     100.0%
%
%   **加入 400 個硬負樣本之後，偵測框從 509 變成 4（正好是真實目標數），
%   precision 從 0.8% 跳到 100%。**
%
%   而且第二輪再挖，找到 **0 個**硬負樣本——一輪就收斂了。
%
%   注意 patch 測試集的準確率**兩輪都是 1.0000**。
%   > **patch 層級的指標完全無法反映偵測器的好壞。**
%
%   它為什麼有效
%   ------------
%   原始訓練集裡每個 patch 都「置中且完整」，而且**一定有一個形狀**——
%   沒有「空白背景」這一類。但滑動視窗送進來的絕大多數視窗
%   是空白或只框到一半。
%
%   分類器被迫在見過的類別裡選一個，而一塊空白的 HOG 特徵
%   恰好可能最接近圓。
%
%   硬負樣本挖掘做的事，就是**把推論時真的會遇到的輸入補進訓練集**。
%   這不是在讓模型變強，是在**修正訓練分布**。
%
%   > 這與第 12 章「用 fitniqe 為自己的領域重訓模型」是同一個道理：
%   > **模型只在它見過的分布上有效。**
%
%   深度學習怎麼處理這件事
%   ----------------------
%   深度學習偵測器不需要手動挖掘，因為它**訓練時就在整張影像上算損失**——
%   所有背景位置自然都是負樣本。
%   （實務上仍有正負樣本極度不平衡的問題，用 focal loss 之類的方法處理。）
%
%   這是第 19 章要對照的三件事之一。
%
%   實務注意
%   --------
%   1. **挖掘要在「訓練集的影像」上做，不是測試影像。**
%      本章為了示範在同一張場景上挖掘與評估，這在真實專案中
%      等於**資料洩漏**——會高估效能。正確做法見練習 3。
%   2. 一輪通常不夠。反覆挖掘到「挖不到新的」為止，
%      本函式回傳空陣列時就是收斂了。
%   3. `MaxSamples` 要限制，否則第一輪可能收到數千個樣本而讓訓練變慢。
%
%   範例：
%     hard = ch16_mineHardNegatives(scene, gtBoxes, svmModel, [32 32]);
%     fprintf("收集到 %d 個硬負樣本\n", size(hard,3));
%
%     featHard = ch16_hogFeatures(hard, [8 8]);
%     featNew  = [featTrain; featHard];
%     yNew     = [yTrain; repmat(categorical("other", ...
%                  ["other" "circle"]), size(featHard,1), 1)];
%     model2   = fitcsvm(featNew, yNew, KernelFunction="linear");
%
%   另見 CH16_SLIDINGWINDOW, CH16_EVALDETECTIONS, FITCSVM.

arguments
    I       {mustBeNumeric, mustBeNonempty}
    gtBoxes {mustBeNumeric}
    model
    winSize (1,2) double {mustBePositive, mustBeInteger}
    options.Stride        (1,1) double {mustBePositive, mustBeInteger} = 8
    options.CellSize      (1,2) double {mustBePositive, mustBeInteger} = [8 8]
    options.MaxSamples    (1,1) double {mustBePositive, mustBeInteger} = 400
    options.PositiveClass (1,1) string = "circle"
    options.IoUThreshold  (1,1) double {mustBeInRange(options.IoUThreshold,0,1)} = 0.5
end

if size(I,3) > 1
    I = im2gray(I);
end
I = im2double(I);

hardNegatives = zeros(winSize(1), winSize(2), 0);
count = 0;

for r = 1:options.Stride:(size(I,1) - winSize(1) + 1)
    for c = 1:options.Stride:(size(I,2) - winSize(2) + 1)
        patch = I(r:r+winSize(1)-1, c:c+winSize(2)-1);
        f = extractHOGFeatures(patch, CellSize=options.CellSize);

        if predict(model, f) ~= options.PositiveClass
            continue                    % 判對了，不是硬負樣本
        end

        % 被判成正類別。檢查它是不是真的碰到某個目標
        box = [c, r, winSize(2), winSize(1)];
        if ~isempty(gtBoxes)
            maxOverlap = max([0, bboxOverlapRatio(box, gtBoxes)]);
            if maxOverlap >= options.IoUThreshold
                continue                % 這是真的命中，不算誤判
            end
        end

        count = count + 1;
        hardNegatives(:,:,count) = patch;
        if count >= options.MaxSamples
            warning("ch16_mineHardNegatives:maxSamplesReached", ...
                "已收集到上限 %d 個硬負樣本就停止掃描。" + ...
                "實際的誤判數可能更多——" + ...
                "這代表模型還很差，需要多輪挖掘。", options.MaxSamples);
            return
        end
    end
end
end
