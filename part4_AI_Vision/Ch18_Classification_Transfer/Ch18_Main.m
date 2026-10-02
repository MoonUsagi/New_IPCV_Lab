%[text] # 第 18 章　影像分類與遷移學習
%[text] {"align":"left"}IPCV\_Lab 課程教材　｜　MATLAB R2026b　｜　難度：\[基礎\]　｜　建議時數：4 小時
%[text] ## 學習目標
%[text] 讀完本章並完成練習後，你應該能夠：
%[text] 1. 說出遷移學習的三種策略，以及各自什麼時候該用
%[text] 2. **不做任何訓練**就完成一次遷移學習（特徵抽取 + 淺層分類器）
%[text] 3. **量測**該從哪一層抽特徵，而不是憑直覺選
%[text] 4. 說出為什麼「ImageNet 分數越高的骨幹，遷移特徵越好」是錯的
%[text] 5. 讀懂 `trainingOptions` 的每一個關鍵設定，並說出設錯的症狀
%[text] 6. 用三種可解釋性方法交叉驗證一個分類決定 \
%[text] ## 前置知識
%[text] 第 17 章（datastore 與資料管線）。本章直接用它的 §3、§4、§6。
%[text] ## 環境需求
%[text] Deep Learning Toolbox、Statistics and Machine Learning Toolbox。
%[text] > **關於訓練：本章的微調段落預設「只組好程式碼、不執行訓練」。**
%[text] > 原因寫在 §8。本章**所有的量化結論都來自 §4–§7 的
%[text] > 特徵抽取路線**，那條路線幾秒鐘就跑完，而且是真實的數字。
%[text] > **關於數字：本章刻意不把準確率寫死在敘述裡。**
%[text] > §6.1 會量出「同一份資料重跑五次，準確率的全距是 2–5 個百分點」，
%[text] > 所以你在自己機器上跑出來的數字**一定和我的不同**。
%[text] > 敘述裡引用的是某一次執行的範例，重點在**效應量的等級**
%[text] > （20 個百分點 vs 2 個百分點），不在小數第三位。
assert(exist("ch18_transferSVM","file") == 2, ...
    "請先切換到課程根目錄並執行 ipcvSetup。");
rng(0);

if gpuDeviceCount > 0
    g = gpuDevice;
    fprintf("GPU：%s，可用 %.2f GB / 總 %.2f GB\n", ...
        g.Name, g.AvailableMemory/1e9, g.TotalMemory/1e9);
else
    disp("沒有 GPU，將使用 CPU（會慢，但本章不需要訓練，可以接受）。")
end
%%
%[text] # 1. 這一章的位置：第一個端到端深度學習任務
%[text] 前十七章的工具都是**沒有學習參數**的（濾波器、形態學、
%[text] 手工特徵），或者是**別人訓練好的**（SAM、Grounding DINO）。
%[text] 這一章開始，模型的權重要為**你的任務**而改變。
%[text] 而第一件要接受的事是：**你幾乎永遠不該從零訓練。**
%[text:table]
%[text] | 做法 | 需要的資料量 | 需要的算力 |
%[text] | --- | --- | --- |
%[text] | 從零訓練 | 數萬至數百萬張 | 數天 GPU |
%[text] | **遷移學習** | **數十至數千張** | **數分鐘至數小時** |
%[text:table]
%[text] 理由是低層視覺特徵（邊緣、紋理、形狀組合）在所有影像任務上
%[text] 大致通用，而那佔了網路絕大部分的參數。
%[text] > **這一章的核心技能不是「會呼叫 trainnet」，
%[text] > 是「知道哪些設定會決定成敗，以及怎麼量」。**
%%
%[text] # 2. `imagePretrainedNetwork`：載入與檢視
%[text] R2024a 起，所有預訓練影像網路都從這一個函式取得。
[net, classNames] = imagePretrainedNetwork("resnet18");
fprintf("\nresnet18：%s，%d 層，輸入 %s，%d 個類別\n", ...
    class(net), numel(net.Layers), ...
    mat2str(net.Layers(1).InputSize), numel(classNames));
fprintf("輸出層：%s\n", strjoin(string(net.OutputNames), ", "));
%[text] 先確認它真的會分類——拿一張 ImageNet 認得的東西試：
I = imread("peppers.png");
X = single(imresize(I, net.Layers(1).InputSize(1:2)));
scores = predict(net, dlarray(X, "SSCB"));
[bestScore, classIdx] = max(extractdata(scores));
fprintf("peppers.png -> 「%s」（分數 %.3f）\n", ...
    string(classNames(classIdx)), bestScore);
%%
%[text] ## 2.1 一個會卡住的 API 限制
%[text] 做遷移學習時要換掉分類頭，做法是傳 `NumClasses`：
%[text] ```matlab
%[text] net = imagePretrainedNetwork("resnet18", NumClasses=10);
%[text] ```
%[text] **但這時候只能有一個輸出引數。** 寫成
%[text] ```matlab
%[text] [net, classes] = imagePretrainedNetwork("resnet18", NumClasses=10);   % ← 錯
%[text] ```
%[text] 會報：
%[text] > `For transfer learning workflows or when Weights is "none",`
%[text] > `the function must have one output argument only.`
%[text] 合理（新的分類頭還沒有類別名稱），但很容易中——
%[text] 因為上面 §2 剛剛才用兩個輸出引數寫過。
netTL = imagePretrainedNetwork("resnet18", NumClasses=10);
fprintf("\n換掉分類頭之後：最後一層是 %s\n", class(netTL.Layers(end)));
clear netTL
%%
%[text] # 3. 遷移學習的三種策略
%[text:table]
%[text] | 策略 | 骨幹 | 訓練什麼 | 何時用 |
%[text] | --- | --- | --- | --- |
%[text] | **一：特徵抽取** | **凍結** | 一個淺層分類器（SVM／softmax） | 資料很少、要快速驗證可行性 |
%[text] | 二：微調分類頭 | 凍結 | 新的分類頭（用梯度） | 資料中等、領域接近 |
%[text] | 三：全網路微調 | **更新** | 全部權重 | 資料較多、領域差很遠 |
%[text:table]
%[text] **策略一的價值常被低估。** 它的優點是：
%[text] - **不需要 GPU**（推論可在 CPU 跑）
%[text] - 訓練是**凸最佳化**：沒有學習率、沒有 epoch、**不會發散**
%[text] - 幾秒鐘就有結果，適合先回答「這個任務有沒有搞頭」
%[text] - 樣本很少時（每類幾十張）它常常**贏過**微調
%[text] > **本章接下來三節走策略一，因為它能給出真實可驗證的數字。**
%[text] > 策略二／三的程式碼在 §8，完整但預設不執行。
%%
%[text] # 4. 策略一實作：完全不用訓練的遷移學習
%[text] 用第 17 章的 datastore 管線準備資料。
digitDir = fullfile(matlabroot, "toolbox", "nnet", "nndemos", ...
    "nndatasets", "DigitDataset");
imdsAll = imageDatastore(digitDir, IncludeSubfolders=true, ...
    LabelSource="foldernames");

% **切分前重設隨機種子。** 前面幾節也用了隨機數（predict 的
% 批次順序等），若不重設，改動前面的程式碼就會讓這裡的切分改變，
% 後面所有的數字都跟著動——我第一版就是這樣，兩次執行的
% 骨幹排名完全不同（§6.1 會說明那件事的真正意義）。
rng(0);
% 每類 60 張，再切 40 訓練／20 測試
imdsSub = splitEachLabel(imdsAll, 60, "randomized");
[dsTrain, dsTest] = splitEachLabel(imdsSub, 0.67, "randomized");
fprintf("\n訓練 %d 張、測試 %d 張、%d 類\n", ...
    numel(dsTrain.Files), numel(dsTest.Files), ...
    numel(categories(dsTrain.Labels)));

[mdl, rep] = ch18_transferSVM(net, dsTrain, dsTest, "pool5");
fprintf("\n=== 策略一結果 ===\n");
fprintf("特徵層 %s、維度 %d\n", rep.Layer, rep.NumFeatures);
fprintf("準確率 **%.4f**\n", rep.Accuracy);
fprintf("抽特徵 %.1f 秒、擬合分類器 %.2f 秒\n", rep.SecExtract, rep.SecFit);
%[text] **準確率約 0.81–0.86（見上方實際輸出），而我們一次梯度都沒算。**
%[text] 但這個數字要放在脈絡裡看：**一個為 MNIST 設計的小型 CNN
%[text] 從零訓練就能到 99% 以上。**
%[text] ImageNet 的特徵在 28×28 的手寫數字上只能到 85% 上下，
%[text] 因為這兩個領域差得很遠——自然彩色照片 vs 二值筆劃。
%[text] > **遷移學習不是魔法，它的效果取決於領域距離。**
%[text] > 這個結論不能從「ImageNet 網路很強」推出來，只能量。
%%
%[text] # 5. 從哪一層抽特徵？——一個直覺會出錯的問題
%[text] 常見的說法是：「淺層學通用特徵（邊緣、紋理），深層學任務特有的
%[text] 語意特徵；**所以領域差很遠的時候應該用淺層**。」
%[text] 這句話聽起來很有道理。**來量一下。**
layers = ["res2b_relu" "res3b_relu" "res4b_relu" "res5b_relu" "pool5"];
sweepTbl = ch18_layerSweep(net, dsTrain, dsTest, layers);
disp(sweepTbl)

figure
plot(1:numel(layers), sweepTbl.("準確率"), "o-", LineWidth=2, MarkerSize=8)
xticks(1:numel(layers)); xticklabels(layers); xtickangle(30)
ylabel("測試準確率"); ylim([0 1]); grid on
title("從哪一層抽特徵（resnet18 -> 手寫數字）")
%[text] 某一次執行的結果（**你的數字會不同，見 §6.1**）：
%[text:table]
%[text] | 層 | 維度 | 準確率 |
%[text] | --- | --- | --- |
%[text] | `res2b_relu` | 64 | 0.21 |
%[text] | `res3b_relu` | 128 | 0.20 |
%[text] | `res4b_relu` | 256 | 0.55 |
%[text] | `res5b_relu` | 512 | **0.85** |
%[text] | `pool5` | 512 | **0.83** |
%[text:table]
%[text] **越深越好，而且差距巨大：20% → 85%，差了 65 個百分點。**
%[text] 但**不要說它「單調上升」**——`res2b_relu` 有時會
%[text] 比 `res3b_relu` 高一點點。那 1 個百分點是**雜訊**，不是訊號。
%[text] **能站得住的結論是那些「大跳」**：
%[text] 0.20 → 0.55 → 0.85，每一步都是 30 個百分點的等級，
%[text] 遠超過 §6.1 量到的雜訊幅度。
%[text] **那個「用淺層」的直覺錯了。** 它混淆了兩件事：
%[text:table]
%[text] | 說法 | 對不對 |
%[text] | --- | --- |
%[text] | 淺層特徵比較**通用** | ✓ 對 |
%[text] | 淺層特徵比較**有用** | ✗ **不一定** |
%[text:table]
%[text] **通用不等於有用。** `res2b_relu` 的 64 個通道大致是
%[text] 有向邊緣與顏色斑塊的響應，而**手寫數字全部都是黑白的邊緣**——
%[text] 這些特徵對「這是 3 還是 8」幾乎沒有判別力。
%[text] 深層特徵雖然是為 ImageNet 的語意調出來的，
%[text] 但它們編碼了**形狀的組合方式**，而那正是區分數字需要的。
%[text] > **「領域差很遠就用淺層」要先量再用。**
%[text] > 它在某些任務上成立（例如純紋理分類），在這裡不成立。
%[text] ## 5.1 `pool5` 與 `res5b_relu` 應該完全一樣，但差了 0.5 個百分點
%[text] `pool5` 就是 `res5b_relu` 的全域平均池化，
%[text] 而 `ch18_extractFeatures` 對卷積層做的也是同一件事。
%[text] **所以兩者的特徵在數學上是同一個東西。**
%[text] 可是它們的準確率通常差個 0.5–2 個百分點。來查為什麼。
Fa = ch18_extractFeatures(net, dsTest, "pool5");
Fb = ch18_extractFeatures(net, dsTest, "res5b_relu");
dmax = max(abs(Fa - Fb), [], "all");
fprintf("%s兩種特徵的最大絕對差 = %.3e（相對 %.3e）%s", ...
    newline, dmax, dmax/mean(abs(Fa(:))), newline);
fprintf("完全相同？%s%s", string(isequal(Fa, Fb)), newline);
%[text] **最大絕對差 1.4e-06，而 `isequal` 回傳 false。**
%[text] 數學上相同，**數值上不同**——`single` 精度下
%[text] 累加的順序不一樣，結果就差在小數第六位。
%[text] 而那個 1.4e-06 的差異，足以讓 SVM 的**邊界樣本**翻面，
%[text] 於是 200 張測試影像裡多對／少對幾張，準確率就跟著動。
%[text] > **這不是 bug，是測量解析度的問題。**
%[text] > 一個 200 張的測試集，最小可分辨單位就是 0.5 個百分點。
%[text] > **報告一個 0.5 個百分點的「改善」時，
%[text] > 你可能只是報告了一次浮點捨入。**
%[text] 原本我想把「兩者準確率完全相同」當成一個免費的自我檢查。
%[text] 實測之後那個檢查要改寫成：
%[text] **兩者的特徵差異應該在 1e-5 以內**（而不是準確率相同）。
%[text] **檢查數值本身，不要檢查一個經過分類器放大的下游指標。**
%%
%[text] # 6. 換一個骨幹有沒有用？
%[text] 直覺：ImageNet 分數越高的網路，特徵應該越好。**量一下。**
backbones = ["resnet18" "mobilenetv2" "resnet50" "darknet19"];
bbTbl = ch18_backboneSweep(backbones, dsTrain, dsTest);
disp(bbTbl)
%[text] 三次不同執行的結果（**排名每次都不一樣**）：
%[text:table]
%[text] | 骨幹 | 維度 | 第 1 次 | 第 2 次 | 第 3 次 |
%[text] | --- | --- | --- | --- | --- |
%[text] | `resnet18` | 512 | 0.900 | **0.905** | 0.845 |
%[text] | `mobilenetv2` | 1280 | **0.925** | 0.900 | **0.890** |
%[text] | `resnet50` | 2048 | 0.900 | 0.840 | 0.845 |
%[text] | `darknet19` | 1000 | 0.895 | 0.860 | 0.880 |
%[text:table]
%[text] **三次執行，冠軍換了兩次。**
%[text] > **我第一版的教材就是在這裡出錯的。** 我看到第 1 次的結果
%[text] > （`mobilenetv2` 0.925 最高），寫下「最小的網路贏了，
%[text] > 而且也最快」，還替它編了一套說法。
%[text] > **第二次執行就推翻了它。**
%[text] > 那個結論不是發現，是雜訊。
%[text] **在下結論之前，必須先知道雜訊有多大。** 這就是 §6.1。
%%
%[text] # 6.1 這些差異能不能分辨？——先量雜訊，再下結論
%[text] **最直接的做法：把同一件事重跑幾次。**
%[text] 資料一樣、切分一樣、程式碼一樣——理論上應該得到一樣的答案。
if ipcvFast()
    nRep = 3;
    disp("（快速模式：重複 3 次。完整執行 5 次。）")
else
    nRep = 5;
end
[repTbl, repInfo] = ch18_repeatability(net, dsTrain, dsTest, "pool5", ...
    NumRepeats=nRep);
%[text] **同一份資料、同一段程式碼，準確率就是會跳。**
%[text] 兩次不同執行量到的五連發：
%[text:table]
%[text] | 執行 | 五次的準確率 | 標準差 | 全距 |
%[text] | --- | --- | --- | --- |
%[text] | A | 0.810／0.855／0.845／0.830／0.860 | 0.0203 | **0.050** |
%[text] | B | 0.830／0.850／0.845／0.835／0.840 | 0.0079 | **0.020** |
%[text:table]
%[text] **連「不穩定的程度」本身都不穩定**（全距 2–5 個百分點）。
%[text] 看你自己那一次的實際輸出。
%[text] 為什麼？兩個原因疊在一起：
%[text] **① GPU 推論不是逐位元決定性的。** cuDNN 會依當下狀況挑不同的
%[text] 卷積演算法，而浮點加法**不符合結合律**，
%[text] 所以累加順序不同就得到略微不同的特徵——正是 §5.1 量到的 1.4e-06。
%[text] **② 分類器把微小差異放大成離散的翻面。**
%[text] 落在決策邊界附近的樣本，特徵差 1e-06 就可能換邊。
%[text] 200 張測試影像裡，一張就是 0.5 個百分點。
%[text] ## 三種變異來源的比較
%[text] 另外量「換切分」的變異（5 個不同的 rng 種子）：
%[text:table]
%[text] | 變異來源 | 標準差 | 全距 |
%[text] | --- | --- | --- |
%[text] | 同一切分重跑（GPU 非決定性） | 0.0203 | 0.0500 |
%[text] | 換切分（抽樣 + 訓練集變動） | **0.0344** | **0.0850** |
%[text] | 二項理論下限（p=0.86, n=200） | 0.0248 | — |
%[text:table]
%[text] 準確率是比例，它的理論標準誤是
%[text] $\text{SE} = \sqrt{p(1-p)/n}$：
nTest = numel(dsTest.Labels);
pHat = repInfo.Mean;
se = sqrt(pHat*(1-pHat)/nTest);
fprintf("%s測試集 n = %d、平均準確率 %.4f%s", newline, nTest, pHat, newline);
fprintf("二項標準誤 = %.4f，95%% 信賴區間約 ± %.1f 個百分點%s", ...
    se, 100*1.96*se, newline);
nNeeded = ceil(pHat*(1-pHat)*(1.96/0.01)^2);
fprintf("要可靠分辨 1 個百分點的差異，測試集需要 n ≈ %d%s", nNeeded, newline);
%[text] **要可靠分辨 1 個百分點，測試集需要約 5,000 張影像。**
%[text] 我們有 200 張。
%[text] 回頭看 §6 的骨幹表格：四個骨幹的差距是 1–6 個百分點，
%[text] 而**重跑同一件事就會差 2–5 個百分點**。
%[text] > **用這個測試集分辨不出這四個骨幹。**
%[text] > 不是「差異不顯著」這種客套話——
%[text] > 是**連重跑同一份程式碼都會差這麼多**。
%[text] 所以這一節能站得住的結論只有一個，而且它是個**否證**：
%[text] **沒有證據支持「參數更多、ImageNet 分數更高的骨幹，
%[text] 遷移特徵就更好」。** `resnet50` 的參數量約是 `resnet18` 的 2 倍、
%[text] ImageNet top-1 高約 6 個百分點，而它在這裡**沒有比較好**
%[text] （測到的是比較差，但差異在雜訊邊緣）。
%[text] 實務上的建議沒有變，只是理由更誠實：
%[text] **先用最小的骨幹試**——它最快、最省顯示記憶體，
%[text] 而且**你沒有證據說大的會更好**。
%[text] > **這一節是整章最重要的方法論。**
%[text] > 第 5 節的「越深越好」站得住，因為那些差距是 30–65 個百分點；
%[text] > 第 6 節的骨幹排名站不住，因為差距只有幾個百分點。
%[text] > **同一個測試集，有些結論能下、有些不能——
%[text] > 差別在效應量與雜訊的比值。**
%[text] 怎麼辦？三個選項，成本遞增：
%[text] 1. **擴大測試集**（最直接，但標註成本線性成長）
%[text] 2. **重複多次，報平均 ± 標準差**（練習 2 會做）
%[text] 3. **交叉驗證**（第 16 章練習 3 用過）
%[text] 還有一個**零成本**的：
%[text] 4. **固定隨機種子並在 CPU 上跑**，可以消掉 GPU 非決定性那一項，
%[text]    但**消不掉抽樣變異**（那一項還更大）。
%[text]    所以它讓數字可重現，但不讓結論變可靠——
%[text]    **可重現不等於可靠。**
%[text] 注意 `ch18_backboneSweep` 是用**層的類別**
%[text] （`GlobalAveragePooling2DLayer`）去找池化層，不是用層名——
%[text] 因為每個骨幹的層名都不一樣（`pool5`／
%[text] `global_average_pooling2d_1`／`avg_pool`／`avg1`）。
%[text] **寫死層名的程式碼換一個骨幹就壞掉。**
%%
%[text] # 7. 混淆矩陣：不要只看一個數字
%[text] 那個約 0.85 的準確率底下藏著什麼？
figure
cm = confusionchart(rep.ConfusionMatrix, rep.ClassNames);
cm.Title = sprintf("resnet18 pool5 + ECOC（準確率 %.4f）", rep.Accuracy);
cm.RowSummary = "row-normalized";

fprintf("\n逐類別 recall：\n");
for k = 1:numel(rep.ClassNames)
    fprintf("  %-4s %.4f\n", rep.ClassNames(k), rep.PerClassRecall(k));
end
fprintf("\n最好 %.4f、最差 %.4f、全距 %.4f\n", ...
    max(rep.PerClassRecall), min(rep.PerClassRecall), ...
    max(rep.PerClassRecall) - min(rep.PerClassRecall));
%[text] **整體準確率是一個平均值，它會把最差的類別藏起來。**
%[text] 這是第 17 章 §3 那件事的延續：不平衡的資料集上
%[text] 整體準確率會騙人；**即使資料是平衡的**（這裡每類 20 張測試），
%[text] 整體準確率仍然掩蓋了逐類別的差異。
%[text] 某次執行：整體 0.8100，但**最差的類別 recall 只有 0.4000**，
%[text] 最好的是 1.0000——**全距 60 個百分點**。
%[text] 這個差距遠大於 §6.1 量到的 5 個百分點雜訊，所以它是真的。
%[text] （哪一個類別最差會隨切分改變，但「有一個類別明顯落後」
%[text] 這件事很穩定。）
%[text] `ch18_transferSVM` 會在某個類別明顯落後時**主動發警告**，
%[text] 因為這是「一個數字看起來很好但模型不能用」最常見的來源。
%[text] > **報告分類器效能時，至少要給混淆矩陣。**
%[text] > 只給一個準確率等於沒說。
%%
%[text] # 8. 策略二／三：微調（程式碼完整，預設不執行）
%[text] **這一節的程式碼是完整可執行的，但預設不訓練。**
%[text] 理由：
%[text] 1. 本章的教學目標是「看懂結構與設定」，不是「跑出一個模型」
%[text] 2. 訓練要數分鐘到數小時，教材就無法自動驗證
%[text] 3. **策略一已經給了真實的數字可以討論**（§4–§7）
%[text] 要真的訓練，把 `DoTrain=true` 傳進去就好。
prep = @(ds) transform(ds, @(I) {imresize(repmat(I,1,1,3), [224 224])});

[netFT, infoFT] = ch18_fineTune("resnet18", ...
    prep(dsTrain), prep(dsTest), 10, ...
    DoTrain=false, FreezeBackbone=true, MaxEpochs=6, MiniBatchSize=16);

fprintf("\n策略：%s\n", infoFT.Strategy);
clsFT = arrayfun(@(L) string(class(L)), netFT.Layers);
iFC = find(contains(clsFT, "FullyConnected"), 1, "last");
iConv = find(contains(clsFT, "Convolution2D"), 1, "first");
fprintf("最後全連接層 %s：WeightLearnRateFactor = %g\n", ...
    netFT.Layers(iFC).Name, netFT.Layers(iFC).WeightLearnRateFactor);
fprintf("第一個卷積層 %s：WeightLearnRateFactor = %g（凍結）\n", ...
    netFT.Layers(iConv).Name, netFT.Layers(iConv).WeightLearnRateFactor);
clear netFT
%[text] **「凍結」的實作方式是把學習率因子設成 0**，
%[text] 而不是把層拿掉。這樣前向傳播照舊，只是梯度不更新那些權重。
%[text] 而新的分類頭給 **10 倍**的學習率因子——
%[text] 骨幹是預訓練好的、新頭是隨機初始化的，
%[text] 兩者用同一個學習率的話，新頭學得太慢。
%%
%[text] # 9. `trainingOptions`：三個設錯會失敗的地方
%[text:table]
%[text] | 設定 | 這裡的值 | 設錯的症狀 |
%[text] | --- | --- | --- |
%[text] | `InitialLearnRate` | **1e-4** | 太大 → 前幾個 iteration loss 就爆掉，或比從零訓練還差 |
%[text] | `MiniBatchSize` | **16** | 太大 → CUDA out of memory（T550 只有 4.29 GB） |
%[text] | `ValidationData` | 必給 | 不給 → **看不到過擬合**，而遷移學習在小資料上非常容易過擬合 |
%[text:table]
%[text] **① 學習率要比從零訓練小 10–100 倍。**
%[text] 從零訓練的典型值是 1e-2，微調是 1e-4。
%[text] 預訓練權重已經在一個好的位置，大學習率會直接把它們破壞掉。
%[text] **② 批次大小是顯示記憶體的直接函數。**
%[text] `resnet18` + 224×224 + 批次 16 在 4.29 GB 上大約剛好；
%[text] 改成 32 就可能 OOM。看到 CUDA out of memory
%[text] **要調的就是批次大小，不是別的**。
%[text] **③ 沒有驗證集就看不到過擬合。**
%[text] 骨幹的容量遠大於你的資料量，所以一定會過擬合，
%[text] 問題只是你有沒有看到。這裡還設了
%[text] `ValidationPatience=3` 與 `OutputNetwork="best-validation"`：
%[text] 連 3 次驗證沒進步就停，並且回傳**驗證表現最好**的那個網路，
%[text] 不是最後一個。
disp(infoFT.TrainingOptions)
%%
%[text] # 10. 訓練曲線怎麼讀
%[text] 訓練時 `Plots="training-progress"` 會開一個視窗。
%[text] 三種典型形狀與它們的意思：
%[text:table]
%[text] | 訓練 loss | 驗證 loss | 診斷 | 怎麼辦 |
%[text] | --- | --- | --- | --- |
%[text] | 下降 | **上升** | **過擬合** | 加擴增、凍結更多層、early stopping |
%[text] | **兩者都停在高位** | 高 | **欠擬合** | 解凍更多層、提高學習率、訓練更久 |
%[text] | 下降 | 下降但**很跳** | 批次太小或學習率偏大 | 加大批次、降學習率 |
%[text] | **第一個 iteration 就是 NaN** | — | 學習率太大或資料有 NaN | 先降學習率 10 倍再查資料 |
%[text:table]
%[text] > **最重要的一條：訓練 loss 一直下降**不代表任何事。
%[text] > 第 17 章 §5 量到的「標籤不同步」也會讓訓練 loss 下降——
%[text] > 模型會從沒壞的那一半樣本學到東西。
%[text] > **要看的是驗證曲線，而且驗證集必須是乾淨的**
%[text] > （第 17 章 §6 的群組感知切分）。
%%
%[text] # 11. 可解釋性：三種方法，三個不同的問題
%[text] 用 §2 那張 `peppers.png` 與它的預測類別。
[maps, expInfo] = ch18_explain(net, I, classIdx, ...
    DoLIME=~ipcvFast(), NumFeatures=24);

figure
tiledlayout(2,2, TileSpacing="compact")
nexttile; imshow(I); title(sprintf("原圖（預測：%s）", string(classNames(classIdx))))
nexttile
imshow(imresize(I, net.Layers(1).InputSize(1:2))); hold on
imagesc(maps.GradCAM, AlphaData=0.5); colormap jet; hold off
title("Grad-CAM（白箱，快）")
nexttile
imshow(imresize(I, net.Layers(1).InputSize(1:2))); hold on
imagesc(maps.Occlusion, AlphaData=0.5); colormap jet; hold off
title("遮擋敏感度（黑箱）")
nexttile
if isempty(maps.LIME)
    axis off; title("LIME（快速模式略過）")
else
    imshow(imresize(I, net.Layers(1).InputSize(1:2))); hold on
    imagesc(maps.LIME, AlphaData=0.5); colormap jet; hold off
    title("LIME（黑箱，慢）")
end
%[text:table]
%[text] | 方法 | 怎麼算 | 問的問題 | 箱子 |
%[text] | --- | --- | --- | --- |
%[text] | Grad-CAM | 梯度加權的特徵圖 | 網路**內部**哪些位置貢獻大 | 白箱 |
%[text] | 遮擋敏感度 | 逐塊遮住再看分數變化 | 遮住哪裡會讓分數**掉最多** | 黑箱 |
%[text] | LIME | 超像素擾動 + 線性代理模型 | 哪些**區域**能線性解釋這個決定 | 黑箱 |
%[text:table]
%[text] 實測耗時（`resnet18`、224×224）：
%[text:table]
%[text] | 方法 | 秒數 |
%[text] | --- | --- |
%[text] | Grad-CAM | 4.94 |
%[text] | 遮擋敏感度 | 3.14 |
%[text] | LIME（24 超像素） | **12.55** |
%[text:table]
%[text] **黑箱方法的代價是時間，換來的是「不需要拿到模型內部」。**
%[text] 遮擋與 LIME 可以用在你只能呼叫 API 的模型上。
%[text] > **一個容易誤導的細節**：`gradCAM` 回傳的矩陣已經被放大到
%[text] > 輸入尺寸（224×224），**但它的有效解析度只有最後卷積層的 7×7。**
%[text] > 看到一張 224×224 的熱圖，很容易誤以為它有那個精度。
%[text] **三種方法常常不一致，而不一致本身就是資訊。**
%[text] 看到三張圖指向同一個區域，才算比較可靠的證據；
%[text] 只跑一種方法就下結論，是在信任一個你沒驗證過的工具。
%[text] > 這是本課程反覆出現的那條線索在可解釋性上的版本：
%[text] > **一個指標（或一種解釋方法）永遠不夠。**
%%
%[text] # 12. Experiment Manager 與 ViT
%[text] ## 12.1 Experiment Manager
%[text] 超參數掃描不要自己寫 for 迴圈。`experimentManager` 提供：
%[text] - 自動記錄每次試驗的設定與結果（不會弄丟）
%[text] - 貝氏最佳化與網格搜尋
%[text] - 並行執行（有 Parallel Computing Toolbox 時）
%[text] R2026a 起 **Deep Network Designer 可以直接準備預訓練影像網路
%[text] 做遷移學習**，不必先寫程式碼組網路。
%[text] 兩個 App 都是互動式的，本章走程式碼路線是為了**可重現與可批次**。
%[text] ## 12.2 ViT 有一個名稱衝突
%[text] Vision Transformer 在 R2026a 可用，**但函式名稱是 `visionTransformer`，
%[text] 不是 `vit`。** 而且：
fprintf("\nwhich(""vit"")  = %s\n", string(which("vit")));
fprintf("which(""visionTransformer"") = %s\n", ...
    string(which("visionTransformer")));
%[text] **`vit` 解析到 Communications Toolbox 的 Viterbi 解碼器**
%[text] （`comm/commmex/vit.mexw64`）。
%[text] 若你照著某些教學文章寫 `net = vit(...)`，
%[text] 會得到一個和深度學習完全無關的錯誤。
%[text] 另外 `imagePretrainedNetwork` **不支援任何 ViT 名稱**
%[text] （`"vit-base-16"` 等都會報 Unsupported network name）。
%[text] ViT 要用 `visionTransformer`，它需要
%[text] *Computer Vision Toolbox Model for Vision Transformer Network* 支援包。
%%
%[text] # 13. R2026a 注意事項
%[text] 1. **`imagePretrainedNetwork(name, NumClasses=n)` 只能有一個輸出引數。**
%[text] 2. **ViT 的函式是 `visionTransformer`**；`vit` 是 Communications Toolbox 的
%[text]    Viterbi 解碼器（名稱衝突）。
%[text] 3. 部分骨幹需要各自的支援包（例如 `googlenet`）。
%[text]    `Weights="none"` 可拿到未訓練架構，但那對遷移學習沒用。
%[text] 4. 灰階影像餵給 ImageNet 網路要先 `repmat(I,1,1,3)`，
%[text]    否則報通道數不符，而訊息不會提到「灰階」。
%[text] 5. **不同骨幹的池化層名稱完全不同**
%[text]    （`pool5`／`global_average_pooling2d_1`／`avg_pool`／`avg1`）。
%[text]    用層的**類別**去找，不要寫死名字。
%[text] 6. `gradCAM` 回傳的圖已放大到輸入尺寸，**有效解析度仍是最後卷積層的**。
%[text] 7. 每個載入的網路都佔顯示記憶體。**掃描骨幹時用完要 `clear`**——
%[text]    第 17 章 §10.1 量到不清會讓推論安靜地慢好幾倍。
%%
%[text] # 14. 常見陷阱
%[text] 1. **憑直覺選特徵層** → §5 量到 19% vs 90%，差 4.7 倍。
%[text] 2. **以為淺層適合遠領域** → 這裡剛好相反。
%[text] 3. **以為大骨幹一定更好** → §6 的 `resnet50` 和 `resnet18` 同分，
%[text]    而最小的 `mobilenetv2` 贏。
%[text] 4. **直接攤平卷積層輸出當特徵** → 維度差異來自空間解析度，
%[text]    比較不公平。要先全域平均池化。
%[text] 5. **微調用從零訓練的學習率** → 破壞預訓練權重。
%[text] 6. **忘記給新分類頭更大的學習率因子** → 新頭學得太慢。
%[text] 7. **不給 `ValidationData`** → 看不到過擬合。
%[text] 8. **看訓練 loss 判斷成敗** → 訓練 loss 下降什麼都不代表
%[text]    （第 17 章 §5 的標籤不同步也會讓它下降）。
%[text] 9. **只報一個準確率** → §7 顯示它會藏住最差的類別。
%[text] 10. **只跑一種可解釋性方法** → 三種問的不是同一個問題。
%[text] 11. **寫死池化層名** → 換骨幹就壞。
%[text] 12. **掃描骨幹時不 `clear`** → 顯示記憶體累積，安靜地變慢。
%%
%[text] # 15. 本章小結
%[text:table]
%[text] | 主題 | 一句話 |
%[text] | --- | --- |
%[text] | 三種策略 | 資料少就用策略一；它不需要 GPU、不會發散 |
%[text] | **策略一實測** | **約 0.85，一次梯度都沒算** |
%[text] | 85% 的脈絡 | 專用小 CNN 能到 99%——**遷移的效果看領域距離** |
%[text] | **特徵層** | **越深越好（20% → 85%）**，「遠領域用淺層」在這裡是錯的 |
%[text] | **骨幹** | **四個骨幹分不出勝負**（雜訊 5 點 vs 差距 1–6 點） |
%[text] | **測量解析度** | **同一份資料重跑五次，全距 2–5 個百分點** |
%[text] | 混淆矩陣 | 整體準確率會藏住最差的類別 |
%[text] | 微調 | 學習率小 10–100 倍、新頭 10 倍因子、一定要有驗證集 |
%[text] | 可解釋性 | 三種方法問三個問題；Grad-CAM 的細節是插值出來的 |
%[text:table]
%[text] 本章有一個「直覺明確但實測相反」的結論（§5 的特徵層），
%[text] 和一個**我自己先寫錯、被第二次執行推翻的結論**（§6 的骨幹排名）。
%[text] 後者留在教材裡，因為那個錯誤比正確答案更有教學價值：
%[text] > **跑一次實驗得到一個排名，不等於得到一個結論。**
%[text] > 要先問「這個差異大得過雜訊嗎」。
%[text] > 而那個問題有公式可以算，成本是零。
%[text] **這一章要帶走兩個習慣：**
%[text] 1. 遷移學習的每一個選擇都可以在幾十秒內量出來——策略一便宜到沒有理由不量
%[text] 2. **量完之後，先算不確定性，再下結論**
%%
%[text] # 16. 練習
%[text] 練習在 `exercise/Ch18_Exercise.m`，六題加一題加分題。
%%
%[text] # 17. 延伸閱讀與下一章
%[text] - `doc imagePretrainedNetwork` — 所有可用骨幹
%[text] - `doc trainingOptions` — 每個設定的完整說明
%[text] - `doc gradCAM` / `doc imageLIME` — 可解釋性
%[text] - `doc visionTransformer` — ViT（注意不是 `vit`）
%[text] **第 19 章**把分類換成偵測：同樣的遷移學習思路，
%[text] 但要處理「位置」與「多個目標」，評估也從準確率換成 mAP。
%[text] 第 16 章的 patch 準確率 vs 偵測器 precision 那件事會再出現一次。

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline","rightPanelPercent":40}
%---
