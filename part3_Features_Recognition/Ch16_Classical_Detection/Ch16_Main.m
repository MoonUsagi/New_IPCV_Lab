%[text] # 第 16 章　傳統物件偵測（特徵 + 分類器）
%[text] {"align":"left"}IPCV\_Lab 課程教材　｜　MATLAB R2026b　｜　難度：\[基礎\]　｜　建議時數：3 小時
%[text] ## 學習目標
%[text] 讀完本章並完成練習後，你應該能夠：
%[text] 1. 使用內建的 Viola-Jones cascade 偵測器，並說出三個關鍵參數各自的作用
%[text] 2. 完成 HOG + SVM 的完整訓練流程
%[text] 3. **說出為什麼「patch 分類 100% 正確」的模型，當成偵測器會慘不忍睹**
%[text] 4. 實作硬負樣本挖掘（hard negative mining），並量化它的效果
%[text] 5. 使用 ACF 行人偵測器，並避開它的參數陷阱
%[text] 6. 說出傳統偵測卡在哪三件事上——這就是第 19 章深度學習要解決的問題 \
%[text] ## 前置知識
%[text] 第 14 章（HOG 特徵）。本章大量使用 `extractHOGFeatures`。
%[text] ## 環境需求
assert(exist("checkEnvironment","file") == 2, ...
    "請先切換到課程根目錄並執行 ipcvSetup，再回來執行本章。");
checkEnvironment(Chapters="16");
rng(0);
%%
%[text] # 1. 這一章的位置
%[text] 第 14 章學會描述**一個區域**，第 15 章學會從影像讀出**結構化資訊**。
%[text] 這一章問的是：**目標在哪裡？**
%[text] 傳統物件偵測的架構只有三個零件：
%[text] **① 滑動視窗**（在哪裡找） → **② 手工特徵**（怎麼描述） →
%[text] **③ 分類器**（是不是目標）
%[text] 這個架構統治了 2001–2013 年，直到深度學習取代它。
%[text] **但它值得完整做一次，理由有三個：**
%[text] 1. 三個零件**各自的失效方式**都很清楚，比深度學習好診斷
%[text] 2. 在**資料很少**（幾十張）或**算力受限**（嵌入式）時它仍然實用
%[text] 3. **知道它卡在哪裡，才知道深度學習解決了什麼**——
%[text]    第 19 章會直接對照
%[text] > 本章最重要的一節是第 6 節。
%[text] > 那裡會出現一個乍看矛盾的結果：
%[text] > **分類器在測試集上 100% 正確，當成偵測器卻只有 0.8% 的精確度。**
%%
%[text] # 2. Viola-Jones：`vision.CascadeObjectDetector`
%[text] MATLAB 內建多個訓練好的 cascade 模型。先看它們在同一張影像上的表現。
I = imread("visionteam.jpg");
fprintf("\n影像 %s，人工數：**6 張正面人臉**\n\n", mat2str(size(I)));

modelTbl = ch16_cascadeModels(I);
disp(modelTbl)

figure
d = vision.CascadeObjectDetector("FrontalFaceCART");
imshow(insertObjectAnnotation(I, "rectangle", d(I), "face", ...
    Color="yellow", LineWidth=3));
title("FrontalFaceCART")
%[text] 實測（正解 6 張臉；秒數已暖機，仍與機器有關）：
%[text:table]
%[text] | 模型 | 偵測數 | 秒數 |
%[text] | --- | --- | --- |
%[text] | **FrontalFaceCART** | **6** ✓ | 0.066 |
%[text] | **FrontalFaceLBP** | **6** ✓ | **0.013** |
%[text] | UpperBody | 14 | 0.117 |
%[text] | EyePairBig | **0** | 0.023 |
%[text] | EyePairSmall | 4 | 0.027 |
%[text] | LeftEye | 6 | 0.043 |
%[text] | RightEye | 4 | 0.038 |
%[text] | Nose | 1 | 0.064 |
%[text] | Mouth | **15** | 0.038 |
%[text] | ProfileFace | 4 | 0.045 |
%[text:table]
%[text] 兩件事值得注意：
%[text] **① `FrontalFaceLBP` 與 `FrontalFaceCART` 結果相同，但快 5 倍。**
%[text] LBP（Local Binary Pattern）特徵只需要比大小，
%[text] CART 需要算 Haar 特徵的加權和。
%[text] **預設是 CART，但多數情況 LBP 就夠了。**
%[text] **② 部位偵測器（眼、鼻、嘴）單獨使用都很不可靠。**
%[text] `Mouth` 找到 15 個、`Nose` 只找到 1 個、`EyePairBig` 找到 0 個。
%[text] 它們的設計用途是**在已經找到的人臉範圍內**再定位部位，
%[text] 而不是在整張影像上獨立搜尋——用 `UseROI` 搭配人臉框才合理。
%%
%[text] # 3. 三個關鍵參數
paramTbl = ch16_cascadeParameters(I, 6);
disp(paramTbl)
%[text] ## 3.1 `MergeThreshold`：幾個重疊偵測才算數
%[text:table]
%[text] | MergeThreshold | 偵測數（正解 6） |
%[text] | --- | --- |
%[text] | 1 | **15** |
%[text] | 2 | 9 |
%[text] | **4（預設）** | **6** ✓ |
%[text] | 6 | 6 ✓ |
%[text] | 8 | 6 ✓ |
%[text] | 12 | 6 ✓ |
%[text] | 20 | 5 |
%[text:table]
%[text] cascade 會在同一張臉附近產生多個重疊的偵測；
%[text] `MergeThreshold` 要求至少有這麼多個重疊才輸出一個框。
%[text] **有一個很寬的平台區（4–12 都給 6）**——
%[text] 這是好參數的特徵，代表它不敏感。
%[text] 低於 4 時假陽性爆炸（1 → 15 個），高於 12 開始漏抓。
%[text] ## 3.2 `ScaleFactor`：每一層放大多少
%[text:table]
%[text] | ScaleFactor | 偵測數 | 秒數 |
%[text] | --- | --- | --- |
%[text] | 1.01 | **14** | **0.726** |
%[text] | 1.05 | 6 ✓ | 0.119 |
%[text] | **1.10（預設）** | **6** ✓ | 0.065 |
%[text] | 1.20 | 6 ✓ | **0.034** |
%[text] | 1.40 | 3 | 0.018 |
%[text:table]
%[text] 越小 = 掃越多尺度 = **又慢又多假陽性**。
%[text] 1.01 比 1.20 慢 **21 倍**，而且多找出 8 個錯的。
%[text] 這與第 12 章「掃描太密不一定比較好」相通：
%[text] **更細的搜尋會找到更多東西，但不保證是對的東西。**
%[text] ## 3.3 `MinSize`：最小的目標有多大
%[text:table]
%[text] | MinSize | 偵測數 |
%[text] | --- | --- |
%[text] | [20 20] | 6 ✓ |
%[text] | [40 40] | 6 ✓ |
%[text] | **[60 60]** | **0** |
%[text] | [80 80] | 0 |
%[text:table]
%[text] **從 [40 40] 到 [60 60] 直接掉到 0**——
%[text] 這張影像的臉介於 40 到 60 像素之間。
%[text] > **`MinSize` 是最有價值的效能參數。**
%[text] > 設得對可以大幅加速（不用掃小尺度），
%[text] > 但設得太大會**完全失效**而不是逐漸變差。
%[text] 實務上應該**先量測目標的實際尺寸範圍**再設它，
%[text] 而不是憑感覺——這與第 10 章 `imfindcircles` 的 `RadiusRange` 同一個道理。
%%
%[text] # 4. ACF 行人偵測
A = imread("visionteam1.jpg");
detACF = peopleDetectorACF;
[bbACF, scACF] = detect(detACF, A);

fprintf("\npeopleDetectorACF 找到 %d 人\n", size(bbACF,1));
fprintf("分數範圍 %.2f – %.2f\n", min(scACF), max(scACF));

figure
imshow(insertObjectAnnotation(A, "rectangle", bbACF, ...
    compose("%.0f", scACF), Color="cyan", LineWidth=3));
title("peopleDetectorACF")
%%
%[text] ## 4.1 `Threshold` 不是分數門檻
%[text] 這是一個容易誤解的參數。
fprintf("\n%-12s %10s %16s\n", "Threshold", "偵測數", "最低分數");
for th = [-1 0 20 40 60]
    [bb, sc] = detect(detACF, A, Threshold=th);
    if isempty(sc), lo = NaN; else, lo = min(sc); end
    fprintf("%-12d %10d %16.2f\n", th, size(bb,1), lo);
end
%[text] 實測：
%[text:table]
%[text] | Threshold | 偵測數 | 最低分數 |
%[text] | --- | --- | --- |
%[text] | −1 | 5 | 25.49 |
%[text] | 0 | 5 | 23.86 |
%[text] | **20** | **0** | — |
%[text] | 40 | 0 | — |
%[text:table]
%[text] **注意矛盾之處**：`Threshold=0` 時最低分數是 **23.86**，
%[text] 但把 `Threshold` 設成 **20**（低於 23.86）卻得到 **0 個偵測**。
%[text] 如果 `Threshold` 是「分數要大於它」的意思，
%[text] 那 20 應該還留得住那個 23.86 分的偵測才對。
%[text] **原因：`Threshold` 是 cascade 內部各級的分類門檻，不是最終分數的篩選器。**
%[text] 它會改變偵測**過程**（所以 −1 與 0 的最低分數也不同：25.49 vs 23.86），
%[text] 而不是事後過濾。
%[text] > **要依分數過濾，請自己對輸出做 `scores > myThreshold`。**
%[text] > 不要用 `Threshold` 參數——它的尺度與輸出分數不是同一回事。
%%
%[text] # 5. HOG + SVM：完整訓練流程
%[text] 內建模型只能偵測人臉與行人。要偵測**自己的目標**就得訓練。
%[text] 用合成資料示範，這樣正確答案已知、而且可重現。
%[text] **任務**：在含有圓、方、三角的場景中，只偵測**圓**。
patchSize = [32 32];
cellSize  = [8 8];

[Xtrain, Ytrain] = ch16_makePatchSet(150, patchSize, 1);
[Xtest,  Ytest]  = ch16_makePatchSet(60,  patchSize, 2);

figure
tiledlayout(1,6, TileSpacing="compact")
for k = [1 2 151 152 301 302]
    nexttile; imshow(Xtrain(:,:,k)); title(Ytrain(k))
end
sgtitle("訓練用的 patch（置中、完整）")

featTrain = ch16_hogFeatures(Xtrain, cellSize);
featTest  = ch16_hogFeatures(Xtest,  cellSize);
fprintf("\nHOG 維度 %d（patch %dx%d、CellSize [%d %d]）\n", ...
    size(featTrain,2), patchSize, cellSize);
fprintf("訓練 %d 個 patch（圓 %d / 其他 %d）\n", ...
    numel(Ytrain), nnz(Ytrain=="circle"), nnz(Ytrain~="circle"));
%%
%[text] ## 5.1 二元 SVM 與多類 ECOC
yTrainBin = categorical(Ytrain == "circle", [false true], ["other" "circle"]);
yTestBin  = categorical(Ytest  == "circle", [false true], ["other" "circle"]);

t = tic; svmModel = fitcsvm(featTrain, yTrainBin, KernelFunction="linear");
fprintf("\n二元 SVM 訓練 %.3f 秒\n", toc(t));
accBin = mean(predict(svmModel, featTest) == yTestBin);
fprintf("測試集準確率 = %.4f\n", accBin);
disp(confusionmat(yTestBin, predict(svmModel, featTest)))

t = tic; ecocModel = fitcecoc(featTrain, categorical(Ytrain));
fprintf("\n三類 ECOC 訓練 %.3f 秒\n", toc(t));
accEcoc = mean(predict(ecocModel, featTest) == categorical(Ytest));
fprintf("測試集準確率 = %.4f\n", accEcoc);
%[text] **兩個模型的測試集準確率都是 1.0000。**
%[text] 混淆矩陣完全對角（120 個 other 全對、60 個 circle 全對）。
%[text] 這個任務是刻意設計得很簡單的——**因為下一節要證明的事情
%[text] 與分類器的好壞無關。**
%[text] 若分類器本身很爛，第 6 節的結果就可以被歸咎於「模型不夠好」，
%[text] 那就看不到真正的問題了。
%%
%[text] # 6. 本章最重要的一節：100% 準確的分類器，0.8% 精確度的偵測器
%[text] 把訓練好的 SVM 拿去做滑動視窗偵測。
%[text] 場景裡有 **4 個圓**（目標）與 6 個干擾物，位置已知。
[scene, gtBoxes] = ch16_makeSceneWithTruth(480, 640);

figure
imshow(insertObjectAnnotation(scene, "rectangle", gtBoxes, "circle", ...
    Color="green", LineWidth=2));
title(sprintf("測試場景：%d 個目標（綠框）+ 6 個干擾物", size(gtBoxes,1)))

[boxes0, ~, nWin0] = ch16_slidingWindow(scene, svmModel, patchSize, ...
    Stride=8, NumScales=1, CellSize=cellSize);
[prec0, rec0] = ch16_evalDetections(boxes0, gtBoxes);

fprintf("\n滑動視窗（步長 8、單尺度）：\n");
fprintf("  掃描了 %d 個視窗\n", nWin0);
fprintf("  NMS 之後還有 **%d** 個偵測框（真實目標只有 %d 個）\n", ...
    size(boxes0,1), size(gtBoxes,1));
fprintf("  precision = **%.1f%%**、recall = %.1f%%" + "\n", prec0, rec0);
fprintf("  平均每個目標產生 %.1f 個框\n", size(boxes0,1)/size(gtBoxes,1));

figure
imshow(insertObjectAnnotation(scene, "rectangle", boxes0, "", ...
    Color="red", LineWidth=1));
title(sprintf("第 1 輪：%d 個偵測框，precision %.1f%%", size(boxes0,1), prec0))
%[text] 實測結果：
%[text:table]
%[text] | 項目 | 數值 |
%[text] | --- | --- |
%[text] | patch 分類準確率 | **1.0000** |
%[text] | 掃描的視窗數 | 4389 |
%[text] | NMS 之後的偵測框 | **509** |
%[text] | 真實目標 | **4** |
%[text] | **precision** | **0.8%** |
%[text] | recall | 100.0% |
%[text:table]
%[text] **同一個模型，在 patch 測試集上 100% 正確，
%[text] 當成偵測器只有 0.8% 的精確度。**
%[text] ## 6.1 為什麼會這樣
%[text] 因為**訓練資料與實際輸入的分布完全不同**。
%[text:table]
%[text] | | 訓練時看到的 | 滑動視窗實際送進來的 |
%[text] | --- | --- | --- |
%[text] | 目標位置 | 置中 | 任意偏移 |
%[text] | 完整性 | 完整 | 常常只有一半 |
%[text] | 內容 | 一定有一個形狀 | 大部分是**空白背景** |
%[text:table]
%[text] 訓練集裡**從來沒有「空白」這一類**，也沒有「半個圓」。
%[text] 分類器被迫在「圓 / 方 / 三角」裡選一個，
%[text] 而一塊空白或半個圓的 HOG 特徵，恰好可能最接近圓。
%[text] > **這不是模型不夠好，是訓練集不完整。**
%[text] > 分類器只在它見過的分布上有效——這與第 12 章
%[text] > 「預設 NIQE 模型在非自然領域失效」是完全同一件事。
%[text] 注意 **recall 是 100%**：四個圓全部找到了。
%[text] 問題純粹是**假陽性**，而那正是下一節要解決的。
%%
%[text] # 7. 硬負樣本挖掘：一輪就修好
%[text] 解法很直接：**把偵測器答錯的視窗收集起來，當成新的負樣本再訓練。**
%[text] 這叫 hard negative mining（硬負樣本挖掘）。
hardNeg = ch16_mineHardNegatives(scene, gtBoxes, svmModel, patchSize, ...
    Stride=8, CellSize=cellSize, MaxSamples=400);
fprintf("\n收集到 %d 個硬負樣本\n", size(hardNeg,3));

figure
tiledlayout(2,6, TileSpacing="compact")
for k = 1:min(12, size(hardNeg,3))
    nexttile; imshow(hardNeg(:,:,k));
end
sgtitle("硬負樣本：被誤判成「圓」的視窗")

featHard = ch16_hogFeatures(hardNeg, cellSize);
featTrain2 = [featTrain; featHard];
yTrain2 = [yTrainBin; repmat(categorical("other", ["other" "circle"]), ...
    size(featHard,1), 1)];

svmModel2 = fitcsvm(featTrain2, yTrain2, KernelFunction="linear");
acc2 = mean(predict(svmModel2, featTest) == yTestBin);
fprintf("第 2 輪 patch 準確率 = %.4f（仍然是 1.0）\n", acc2);

[boxes1, ~, ~] = ch16_slidingWindow(scene, svmModel2, patchSize, ...
    Stride=8, NumScales=1, CellSize=cellSize);
[prec1, rec1] = ch16_evalDetections(boxes1, gtBoxes);
fprintf("\n第 2 輪偵測：%d 個框、precision %.1f%%、recall %.1f%%" + "\n", ...
    size(boxes1,1), prec1, rec1);

% 再挖一次，看還有沒有
hardNeg2 = ch16_mineHardNegatives(scene, gtBoxes, svmModel2, patchSize, ...
    Stride=8, CellSize=cellSize, MaxSamples=400);
fprintf("第 2 輪再挖：%d 個硬負樣本\n", size(hardNeg2,3));

figure
imshow(insertObjectAnnotation(scene, "rectangle", boxes1, "circle", ...
    Color="red", LineWidth=3));
title(sprintf("硬負樣本挖掘後：%d 個框，precision %.1f%%", ...
    size(boxes1,1), prec1))
%[text] 實測：
%[text:table]
%[text] | 輪次 | 訓練樣本 | 偵測框 | **precision** | recall |
%[text] | --- | --- | --- | --- | --- |
%[text] | 第 1 輪 | 450 | **509** | **0.8%** | 100.0% |
%[text] | **第 2 輪** | 850 | **4** | **100.0%** | 100.0% |
%[text:table]
%[text] **加入 400 個硬負樣本之後，偵測框從 509 變成 4——正好是真實目標數，
%[text] precision 從 0.8% 跳到 100%。**
%[text] 而且**第二輪再挖，找到 0 個硬負樣本**——收斂了。
%[text] 注意 patch 測試集的準確率**兩輪都是 1.0000**。
%[text] > **patch 層級的指標完全無法反映偵測器的好壞。**
%[text] > 這是本課程反覆出現的主題：
%[text] > 第 12 章的品質指標無法預測計數失敗、
%[text] > 第 14 章的重複性無法預測配對能力、
%[text] > 這裡的分類準確率無法預測偵測精確度。
%[text] > **要量的東西，就要直接量它。**
%[text] ## 這一節有一個方法論瑕疵，而且是故意留的
%[text] 上面在**同一張場景**上挖掘硬負樣本，然後在**同一張場景**上評估。
%[text] **那是資料洩漏。** 模型背下了這張場景的誤判位置，
%[text] 所以 100.0% 這個數字是被高估的。
%[text] 練習 3 會用五折交叉驗證量出代價：
%[text:table]
%[text] | 評估方式 | precision | recall |
%[text] | --- | --- | --- |
%[text] | 在訓練場景上（本節的做法） | 100.0% ± 0.0 | 70.0% ± 27.4 |
%[text] | 在留出場景上（正確做法） | **80.0% ± 44.7** | 60.0% ± 37.9 |
%[text:table]
%[text] **precision 高估 20.0 個百分點**，而更值得注意的是標準差：
%[text] 洩漏版 ± 0.0，乾淨版 ± 44.7——**洩漏還會讓變異數消失**，
%[text] 讓你誤以為結果很穩定。
%[text] 留在這裡是因為「一輪就修好」這個機制要先看清楚，
%[text] 而兩張場景會讓敘事變複雜。但**不要把 100.0% 當成本方法的實際效能**。
%[text] 練習 3 也會量到另一件更重要的事：
%[text] 只在**一張**場景上挖掘，換新場景 precision 直接掉到 **0%**；
%[text] 挖 4 張才拉到 80%。**泛化來自挖掘場景的多樣性，不是挖掘本身。**
%%
%[text] # 8. 滑動視窗的計算成本
%[text] 硬負樣本修好了精確度，但**成本問題修不掉**。
if ipcvFast()
    disp("（快速模式：略過成本掃描。完整執行時它要跑 34,708 個視窗、約 2 分鐘。）")
    disp("下面的實測數字是完整執行時量到的。")
else
    costTbl = ch16_slidingWindowCost(scene, svmModel2, patchSize, cellSize);
    disp(costTbl)
end
%[text] 實測（480×640 的單張影像，用**挖掘後**的模型）：
%[text:table]
%[text] | 步長 | 尺度數 | 視窗數 | 秒數 | 偵測數 |
%[text] | --- | --- | --- | --- | --- |
%[text] | 16 | 1 | 1,131 | 1.76 | 4 ✓ |
%[text] | 16 | 3 | 2,276 | 4.53 | 4 ✓ |
%[text] | 8 | 1 | 4,389 | 8.46 | 4 ✓ |
%[text] | 8 | 3 | 8,814 | 15.85 | 4 ✓ |
%[text] | 4 | 1 | 17,289 | 31.36 | 4 ✓ |
%[text] | **4** | **3** | **34,708** | **60.56** | 4 ✓ |
%[text:table]
%[text] **步長減半 → 視窗數 4 倍 → 時間約 4 倍。** 每千個視窗
%[text] 固定花 1.55–1.93 秒，**比值接近常數 → 沒有規模經濟。**
%[text] 一張 480×640 的影像，步長 4、三個尺度要 **60.6 秒**。
%[text] 換算成 30 fps 的即時影片，需要快 **1,800 倍**。
%[text] 注意**偵測數在所有設定下都是 4**（正確）——
%[text] 硬負樣本挖掘之後，精確度不再依賴步長。
%[text] 步長只影響**速度**與**定位精度**，不再影響對錯。
%[text] 三個成本來源：
%[text] 1. **視窗數量**：與 (影像面積 / 步長²) × 尺度數 成正比
%[text] 2. **每個視窗都重算特徵**：相鄰視窗有 75% 的像素重疊，
%[text]    但 HOG 被完整重算了一次
%[text] 3. **每個視窗都跑一次分類器**
%[text] 傳統方法對這三點各有一個補救：
%[text:table]
%[text] | 問題 | 傳統的補救 |
%[text] | --- | --- |
%[text] | 視窗太多 | **cascade**：多數視窗在第一級就被拒絕 |
%[text] | 重複算特徵 | **積分影像**：Haar 特徵可 O(1) 取得 |
%[text] | 尺度太多 | **特徵金字塔近似**（ACF 的核心技巧） |
%[text:table]
%[text] 這就是為什麼內建的 cascade 這麼快：
fprintf("\n%-20s %10s %12s\n", "方法", "偵測數", "秒數");
for m = ["FrontalFaceCART" "FrontalFaceLBP"]
    dd = vision.CascadeObjectDetector(char(m));
    t = tic; bb = dd(I); el = toc(t);
    fprintf("%-20s %10d %12.4f\n", m, size(bb,1), el);
end
fprintf("%-20s %10s %12s\n", "我們的 HOG+SVM", "4", "約 8.5");
%[text] **`FrontalFaceLBP` 在 413×800 的影像上只花 0.013 秒。**
%[text] 我們的 HOG+SVM 在更小的影像上花了 8.46 秒——**慢了 520 倍**。
%[text] 差別不在特徵或分類器，在**架構**：
%[text] cascade 的前幾級只用兩三個特徵，就能拒絕 99% 的視窗。
%%
%[text] # 9. 傳統方法卡在哪裡——第 19 章要解決的三件事
%[text] 把本章的實測結果整理成三個結構性限制：
%[text] **① 特徵是手工設計的，換任務就要重來**
%[text] HOG 是為行人設計的（直立、有明顯垂直邊緣）。
%[text] 換成偵測瑕疵、細胞、文字，就得重新想一組特徵。
%[text] **深度學習的解法**：特徵從資料學出來。
%[text] **② 訓練分布與推論分布不同，必須靠硬負樣本挖掘手動修補**
%[text] 第 6–7 節實測：不挖掘 precision 0.8%、挖掘一輪後 100%。
%[text] 而那一輪挖掘需要你**自己寫程式收集誤判、重新訓練**。
%[text] **深度學習的解法**：訓練時就在整張影像上算損失，
%[text] 負樣本自然包含所有背景位置（以及 focal loss 之類的處理）。
%[text] **③ 滑動視窗的計算量與影像面積成正比，而且特徵重複計算**
%[text] 第 8 節實測：34,708 個視窗、60.6 秒。
%[text] **深度學習的解法**：卷積**共享計算**——
%[text] 整張影像只算一次特徵圖，所有位置共用。
%[text] 這就是 R-CNN → Fast R-CNN → YOLO 這條演進線的核心動機。
%[text] > **三個問題，深度學習各解決了一個。**
%[text] > 但它也帶來新的代價：需要大量標註資料、需要 GPU、
%[text] > 而且**失效時難以診斷**——
%[text] > 傳統方法至少能告訴你「是特徵不夠好」還是「是負樣本不夠」。
%[text] **傳統方法什麼時候仍然是對的選擇：**
%[text] - 資料很少（幾十張，不夠訓練深度模型）
%[text] - 算力受限（嵌入式、無 GPU）
%[text] - 目標外觀高度固定（產線上的同一個零件）
%[text] - 需要可解釋、可逐步除錯
%%
%[text] # 10. R2026a 注意事項
fprintf("\ntrainCascadeObjectDetector 是否存在：%d\n", ...
    exist("trainCascadeObjectDetector", "file") > 0);
fprintf("trainACFObjectDetector      是否存在：%d\n", ...
    exist("trainACFObjectDetector", "file") > 0);
fprintf("evaluateObjectDetection     是否存在：%d\n", ...
    exist("evaluateObjectDetection", "file") > 0);
fprintf("evaluateDetectionPrecision  是否存在：%d\n", ...
    exist("evaluateDetectionPrecision", "file") > 0);
%[text] 三件事：
%[text] **① `trainCascadeObjectDetector` 的 MATLAB Compiler 支援即將移除。**
%[text] 函式本身仍可用，但**不能再編譯進獨立應用程式**。
%[text] 要部署 cascade 偵測器的話，請改用 MATLAB Coder 產生 C 程式碼，
%[text] 或改用可部署的替代方案（第 30 章）。
%[text] **② 評估函式有新舊兩個。**
%[text:table]
%[text] | 函式 | 狀態 |
%[text] | --- | --- |
%[text] | `evaluateDetectionPrecision` | 舊版，仍可用 |
%[text] | **`evaluateObjectDetection`** | **新版，建議使用** |
%[text:table]
%[text] 新版一次回傳多個指標（AP、precision、recall、AOS），
%[text] 而且支援多類別與多個 IoU 門檻。
%[text] **③ 自訓 cascade 需要大量樣本。**
%[text] `trainCascadeObjectDetector` 的官方建議是**數百到數千**個正樣本、
%[text] **數千**個負樣本。本章不做完整訓練（太慢），
%[text] 練習 4 會用 MATLAB 內建的停止標誌資料集做一次小規模訓練。
%%
%[text] # 11. 常見陷阱
%[text] **① 用預設的 `FrontalFaceCART`。**
%[text] `FrontalFaceLBP` 結果相同但**快 5 倍**（第 2 節）。
%[text] **② 單獨用部位偵測器（眼、鼻、嘴）。**
%[text] `Mouth` 在整張影像上找到 15 個、`EyePairBig` 找到 0 個。
%[text] 它們要搭配 `UseROI` 在已找到的人臉範圍內使用（第 2 節）。
%[text] **③ 把 `ScaleFactor` 調小以求「更準」。**
%[text] 1.01 比 1.20 慢 21 倍，而且多出 8 個假陽性（第 3.2 節）。
%[text] **④ 憑感覺設 `MinSize`。**
%[text] 從 [40 40] 到 [60 60]，偵測數直接從 6 掉到 **0**——
%[text] 是懸崖不是斜坡（第 3.3 節）。
%[text] **⑤ 以為 ACF 的 `Threshold` 是分數門檻。**
%[text] `Threshold=0` 時最低分數 23.86，但 `Threshold=20` 得到 **0 個偵測**。
%[text] 它是 cascade 內部的分類門檻，不是事後過濾（第 4.1 節）。
%[text] 要依分數過濾就自己做 `scores > myThreshold`。
%[text] **⑥ 用 patch 分類準確率評估偵測器。**
%[text] 本章的模型 patch 準確率 **1.0000**，偵測 precision **0.8%**（第 6 節）。
%[text] **⑦ 跳過硬負樣本挖掘。**
%[text] 一輪挖掘讓 precision 從 0.8% 變成 100%（第 7 節）。
%[text] 這不是選配步驟，是**必要**步驟。
%[text] **⑧ 低估滑動視窗的成本。**
%[text] 步長減半 → 時間 4 倍。480×640 單張、步長 4、三尺度要 **60.6 秒**（第 8 節）。
%[text] **⑨ 訓練集裡沒有「背景」這一類。**
%[text] 滑動視窗送進來的絕大多數視窗是空白背景，
%[text] 而訓練集裡每個 patch 都一定有一個形狀（第 6.1 節）。
%[text] **⑩ 打算把自訓 cascade 編譯成獨立應用程式。**
%[text] `trainCascadeObjectDetector` 的 MATLAB Compiler 支援即將移除（第 10 節）。
%%
%[text] # 12. 本章小結
%[text] **架構只有三個零件**
%[text] 滑動視窗 + 手工特徵 + 分類器。每個零件都有清楚的失效方式。
%[text] **分類準確率不等於偵測精確度**
%[text] 100% vs 0.8%。這是本章最重要的數字對比。
%[text] 原因是**訓練分布與推論分布不同**，而不是模型不好。
%[text] **硬負樣本挖掘是必要步驟**
%[text] 一輪就把 precision 從 0.8% 推到 100%，第二輪挖到 0 個即收斂。
%[text] **成本是結構性的**
%[text] 視窗數與面積成正比、特徵重複計算。
%[text] cascade 用「提早拒絕」補救，所以 `FrontalFaceLBP` 只要 0.013 秒——
%[text] 比我們的滑動視窗快 **520 倍**。
%[text] **這一章是第 19 章的對照組**
%[text] 深度學習解決的正是這三件事：
%[text] 學特徵、訓練時就見過所有背景、卷積共享計算。
%%
%[text] # 13. 練習
%[text] 練習題在 `exercise/Ch16_Exercise.m`，解答在 `exercise/Ch16_Solution.m`。
%[text] 五題 + 一題加分題，建議 60 分鐘。
%%
%[text] # 14. 延伸閱讀與下一章
%[text] **本章函式**
%[text:table]
%[text] | 檔案 | 用途 |
%[text] | --- | --- |
%[text] | `code/ch16_cascadeModels.m` | 比較內建 cascade 模型 |
%[text] | `code/ch16_cascadeParameters.m` | 三個關鍵參數的掃描 |
%[text] | `code/ch16_makePatchSet.m` | 合成訓練用 patch |
%[text] | `code/ch16_hogFeatures.m` | 批次取 HOG 特徵 |
%[text] | `code/ch16_makeSceneWithTruth.m` | 合成場景並回傳 ground truth |
%[text] | `code/ch16_slidingWindow.m` | 滑動視窗偵測（含 NMS） |
%[text] | `code/ch16_mineHardNegatives.m` | 硬負樣本挖掘 |
%[text] | `code/ch16_evalDetections.m` | precision / recall |
%[text] | `code/ch16_slidingWindowCost.m` | 計算成本掃描 |
%[text:table]
%[text] **官方文件**
%[text] `doc vision.CascadeObjectDetector`、`doc trainCascadeObjectDetector`、
%[text] `doc peopleDetectorACF`、`doc trainACFObjectDetector`、
%[text] `doc extractHOGFeatures`、`doc fitcsvm`、`doc evaluateObjectDetection`
%[text] **下一章**
%[text] 第 17 章　資料標註、資料集與 Datastore——
%[text] Part IV 深度學習的第一步，也是整個 AI 專案最大的成本所在。

% ========================================================================
%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline","rightPanelPercent":40}
%---
