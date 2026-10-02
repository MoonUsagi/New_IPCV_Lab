%[text] # 第 22 章　練習解答
%[text] 工業瑕疵檢測與異常偵測
assert(exist("ch22_loadDataset","file") == 2, ...
    "請先切換到課程根目錄並執行 ipcvSetup。");
rng(0);

if ipcvFast()
    NREP = 2; disp("（快速模式：重複 2 次、掃描點減少。）")
else
    NREP = 3;
end

baseData = ch22_loadDataset();
%%
%[text] # 解答 1：把瑕疵變難，直到方法失效
%[text] 先訓練一次基準模型（良品不變，只換瑕疵的難度）。
[det0, ~] = ch22_trainAnomaly(baseData, "patchcore");
sGood0 = scoreAll(det0, baseData.GoodTest);

if ipcvFast()
    contrasts = [140 100 60 30 10];
else
    contrasts = [140 120 100 80 60 40 20 10 5];
end
sepC = zeros(numel(contrasts),1);
meanBadC = zeros(numel(contrasts),1);
for k = 1:numel(contrasts)
    bad = makeBadSet(baseData.ImageSize, 12, contrasts(k), 10, 0);
    sB = scoreAll(det0, bad);
    sepC(k) = (min(sB) - max(sGood0)) / std(sGood0);
    meanBadC(k) = mean(sB);
end

fprintf("\n%-10s %14s %16s\n", "對比度", "瑕疵平均分數", "分離度(良品std)");
for k = 1:numel(contrasts)
    fprintf("%-10d %14.3f %16.1f\n", contrasts(k), meanBadC(k), sepC(k));
end
%%
%[text] ## 再掃瑕疵大小
if ipcvFast()
    sizes = [13 9 5 3];
else
    sizes = [13 11 9 7 5 4 3 2];
end
sepS = zeros(numel(sizes),1);
meanBadS = zeros(numel(sizes),1);
for k = 1:numel(sizes)
    bad = makeBadSet(baseData.ImageSize, 12, 140, sizes(k), 0);
    sB = scoreAll(det0, bad);
    sepS(k) = (min(sB) - max(sGood0)) / std(sGood0);
    meanBadS(k) = mean(sB);
end

fprintf("\n%-10s %14s %16s\n", "瑕疵邊長", "瑕疵平均分數", "分離度(良品std)");
for k = 1:numel(sizes)
    fprintf("%-10d %14.3f %16.1f\n", sizes(k), meanBadS(k), sepS(k));
end

figure
tiledlayout(1,2, TileSpacing="compact")
nexttile
plot(contrasts, sepC, "o-", LineWidth=1.8); grid on
xlabel("對比度（亮度差）"); ylabel("分離度"); title("對比度 vs 分離度")
yline(0, "r--", "重疊");
nexttile
plot(sizes, sepS, "s-", LineWidth=1.8); grid on
xlabel("瑕疵邊長（像素）"); ylabel("分離度"); title("大小 vs 分離度")
yline(0, "r--", "重疊");

iC = find(sepC <= 0, 1);
iS = find(sepS <= 0, 1);
fprintf("\n對比度低於 %s 時分布開始重疊\n", ...
    ternStr(isempty(iC), "（掃描範圍內都沒重疊）", string(contrasts(min(iC,end)))));
fprintf("瑕疵邊長小於 %s 時分布開始重疊\n", ...
    ternStr(isempty(iS), "（掃描範圍內都沒重疊）", string(sizes(min(iS,end)))));
%[text] ## 量到的結果——**和我的預期相反**
%[text:table]
%[text] | 對比度 | 分離度 | | 瑕疵邊長 | 分離度 |
%[text] | --- | --- | --- | --- | --- |
%[text] | 140 | 589.6 | | 13 | 676.7 |
%[text] | 100 | 399.6 | | 9 | 589.0 |
%[text] | 60 | 217.6 | | 5 | 439.9 |
%[text] | 30 | 97.4 | | 3 | **355.7** |
%[text] | **10** | **7.5** | | | |
%[text:table]
%[text] **對比度從 140 降到 10，分離度掉了 79 倍（589.6 → 7.5）。
%[text] 瑕疵邊長從 13 降到 3，分離度只掉了 1.9 倍（676.7 → 355.7）。**
%[text] **第 6 小題：對比度與大小，哪一個比較致命？**
%[text] **在這個設定下是對比度，而我原本預期是大小。**
%[text] 我的推理是「PatchCore 比較的是下採樣後的特徵，
%[text] 3×3 的瑕疵在特徵圖上不到一個格子就會消失」——
%[text] 那是第 19 章練習 5、第 20 章 §7.1 的同一套邏輯。
%[text] **但資料說不是。**
%[text] 合理的解釋是：**合成瑕疵的對比度太強了**。
%[text] 一個 3×3、亮度差 140 的暗塊，即使在下採樣後的特徵上
%[text] 也會造成明顯的擾動——**強訊號撐得過下採樣**。
%[text] 而對比度降到 10 時，瑕疵和良品的雜訊（標準差 8）幾乎同量級，
%[text] 那時候連原始像素都分不出來，更別說特徵。
%[text] > **但要注意這個結論的適用範圍。**
%[text] > 兩條曲線在掃描範圍內**都沒有真正重疊**（分離度都 > 0），
%[text] > 代表這個合成任務**對 PatchCore 來說太簡單**，
%[text] > 還沒逼到它的真正失效點。
%[text] > **真實瑕疵（低對比 + 小面積 + 不規則形狀）才是考驗。**
%[text] **實務上的做法不變**：先量你的瑕疵在原圖上佔幾個像素、
%[text] 以及它和背景的亮度差，兩個都要量——
%[text] 因為**哪一個致命取決於你的資料，不是取決於理論**。
%%
%[text] # 解答 2：良品訓練集被汙染
contamCounts = [0 1 2 4 8];
meanBadCon = zeros(numel(contamCounts),1);
sepCon = zeros(numel(contamCounts),1);

for k = 1:numel(contamCounts)
    nC = contamCounts(k);
    d = baseData;
    if nC > 0
        % 把瑕疵品混進良品訓練集
        d.GoodTrain = cat(4, d.GoodTrain, baseData.Bad(:,:,:,1:nC));
    end
    detC = ch22_trainAnomaly(d, "patchcore");
    sG = scoreAll(detC, baseData.GoodTest);
    sB = scoreAll(detC, baseData.Bad);
    meanBadCon(k) = mean(sB);
    sepCon(k) = (min(sB) - max(sG)) / std(sG);
    clear detC
end

fprintf("\n%-12s %16s %16s\n", "混入瑕疵數", "瑕疵平均分數", "分離度");
for k = 1:numel(contamCounts)
    fprintf("%-12d %16.3f %16.1f\n", contamCounts(k), meanBadCon(k), sepCon(k));
end

figure
yyaxis left;  plot(contamCounts, meanBadCon, "o-", LineWidth=1.8); ylabel("瑕疵平均分數")
yyaxis right; plot(contamCounts, sepCon, "s--", LineWidth=1.8);   ylabel("分離度")
xlabel("混入良品訓練集的瑕疵張數"); grid on
title("訓練集汙染的代價")
%[text] ## 量到的結果——**一張就毀了**
%[text:table]
%[text] | 混入瑕疵數 | 瑕疵平均分數 | 分離度 |
%[text] | --- | --- | --- |
%[text] | **0** | **22.951** | **716.2** |
%[text] | **1** | **3.932** | **−5.0** |
%[text] | 2 | 4.320 | −5.0 |
%[text] | 4 | 2.999 | −2.9 |
%[text] | 8 | 2.463 | −10.9 |
%[text:table]
%[text] **第 4 小題：汙染幾張就失效？**
%[text] **一張。**
%[text] 24 張良品裡混進 **1 張**瑕疵品，瑕疵的平均分數就從
%[text] 22.951 崩到 3.932，分離度從 +716 變成 **−5（負數代表分布重疊）**。
%[text] > **這比我預期的嚴重得多。** 我原本以為會是「隨數量逐漸下降」，
%[text] > 實際上是**一張就跨過懸崖**。
%[text] 原因在 PatchCore 的機制：它把良品特徵存成 coreset，
%[text] 推論時算「離最近的 coreset 成員多遠」。
%[text] 混進去的那張瑕疵**本身就成了 coreset 的一員**，
%[text] 於是所有同類的瑕疵離它都很近——分數直接塌掉。
%[text] **而整個過程沒有任何錯誤或警告。**
%[text] > **這是本章最重要的實務警告：
%[text] > 良品訓練集的純淨度，比良品的數量重要得多。**
%[text] > 解答 3 會看到多收良品的效益有限，
%[text] > 但這裡一張髒資料就毀掉一切。
%[text] **第 5 小題：怎麼事先偵測汙染**
%[text] 一個可行的做法：**用訓練集自己的留一法分數**。
% 留一法：每次用 N-1 張訓練，對留下的那張評分
dCon = baseData;
dCon.GoodTrain = cat(4, dCon.GoodTrain, baseData.Bad(:,:,:,1:2));  % 混入 2 張
nTr = size(dCon.GoodTrain, 4);
if ipcvFast(), probeIdx = [1 2 nTr-1 nTr]; else, probeIdx = 1:nTr; end
looScores = nan(nTr,1);
for i = probeIdx
    dd = dCon;
    dd.GoodTrain(:,:,:,i) = [];
    dTmp = ch22_trainAnomaly(dd, "patchcore");
    looScores(i) = predict(dTmp, dCon.GoodTrain(:,:,:,i));
    clear dTmp
end
valid = ~isnan(looScores);
fprintf("\n留一法分數（混入 2 張瑕疵，它們是最後 2 張）：\n");
fprintf("  真良品的分數：%s\n", mat2str(round(looScores(valid & (1:nTr)' <= nTr-2)',2)));
fprintf("  混入品的分數：%s\n", mat2str(round(looScores(valid & (1:nTr)' > nTr-2)',2)));
%[text] **留一法能抓到汙染**：被留下的那張瑕疵品，
%[text] 用「其餘良品」訓練出來的模型評分會**明顯偏高**。
%[text] > **但這個檢查有一個前提**：汙染的樣本要夠少。
%[text] > 若訓練集裡有很多同類的瑕疵，留一法時
%[text] > **其他同類的瑕疵還在訓練集裡**，模型就不會覺得它異常。
%[text] **所以留一法能抓「零星汙染」，抓不到「系統性汙染」。**
%[text] 後者只能靠人工抽檢，或者用第 20 章的方式標註一小批來驗證。
%%
%[text] # 解答 3：良品要幾張才夠
if ipcvFast()
    nGoodList = [4 8 16 32];
else
    nGoodList = [4 6 8 12 16 24 32 48];
end
muSep = zeros(numel(nGoodList),1);
sdSep = zeros(numel(nGoodList),1);

bigGood = ch22_loadDataset(NumGoodTrain=64, NumGoodTest=12, NumBad=12, Seed=1);
for k = 1:numel(nGoodList)
    s = zeros(NREP,1);
    for r = 1:NREP
        rng(100*k + r);
        idx = randperm(size(bigGood.GoodTrain,4), nGoodList(k));
        d = bigGood;
        d.GoodTrain = bigGood.GoodTrain(:,:,:,idx);
        detN = ch22_trainAnomaly(d, "patchcore");
        sG = scoreAll(detN, bigGood.GoodTest);
        sB = scoreAll(detN, bigGood.Bad);
        s(r) = (min(sB) - max(sG)) / std(sG);
        clear detN
    end
    muSep(k) = mean(s); sdSep(k) = std(s);
    fprintf("  良品 %2d 張：分離度 %.1f ± %.1f\n", nGoodList(k), muSep(k), sdSep(k));
end

figure
errorbar(nGoodList, muSep, sdSep, "o-", LineWidth=1.8); grid on
xlabel("良品訓練張數"); ylabel("分離度（良品標準差）")
title("良品要幾張才夠")
%[text] ## 量到的結果——**分離度不升反降**
%[text:table]
%[text] | 良品張數 | 分離度 |
%[text] | --- | --- |
%[text] | 4 | **358.6 ± 17.3** |
%[text] | 8 | 318.9 ± 58.3 |
%[text] | 16 | 251.2 ± 45.9 |
%[text] | 32 | 293.1 ± 0.7 |
%[text:table]
%[text] **多給良品，分離度反而下降。這也和直覺相反。**
%[text] 原因在分離度的定義：
%[text] $$\text{分離度} = \frac{\min(\text{瑕疵}) - \max(\text{良品})}{\text{std}(\text{良品})}$$
%[text] 良品越多，**抽到極端良品的機會就越大**，
%[text] $\max(\text{良品})$ 往上、分母也跟著變——
%[text] 所以分離度下降**不代表模型變差**，
%[text] 而是**這個指標對樣本數敏感**。
%[text] > **這是一個指標設計的教訓**：
%[text] > 用極值（min/max）定義的指標會隨樣本數漂移。
%[text] > 要比較不同樣本數的設定，該用**分位數**
%[text] > （例如良品的 99 百分位 vs 瑕疵的 1 百分位）
%[text] > 或直接看重疊比例。
%[text] 注意 32 張時標準差只有 0.7（4 張時是 17.3）——
%[text] **估計本身是穩定了，只是中心值在漂。**
%[text] **第 5 小題：飽和點和什麼有關？**
%[text] **和良品本身的變異程度有關。**
%[text] 合成良品只有高斯雜訊在變，所以**很少張就飽和**——
%[text] coreset 很快就涵蓋了「正常」的範圍。
%[text] > **換到你的產線上這個數字一定會變大，而且可能大很多。**
%[text] > 真實良品會因為光照、擺放角度、批次色差、
%[text] > 甚至鏡頭髒汙而有很大的變異，
%[text] > coreset 必須涵蓋**所有這些正常的變異**，
%[text] > 否則它們會被判成異常（過殺）。
%[text] **實務建議**：良品訓練集要**刻意涵蓋所有已知的正常變異**——
%[text] 不同批次、不同班別、不同光照條件都要收進去。
%[text] 這比「多收幾百張同一批的良品」有用得多。
%%
%[text] # 解答 4：門檻的成本計算
%[text] **第 1 小題：兩個成本**
c_overkill = 20;     % 一次過殺：人工複檢（秒，或折算成金額）
c_escape   = 5000;   % 一次漏檢：流到客戶端（召回、賠償、商譽）
fprintf("\n過殺成本 %.0f、漏檢成本 %.0f（比值 %.0f 倍）\n", ...
    c_overkill, c_escape, c_escape/c_overkill);

sGoodB = scoreAll(det0, baseData.GoodTest);
sBadB  = scoreAll(det0, baseData.Bad);
[thTbl, ~] = ch22_thresholdAnalysis(sGoodB, sBadB, NumPoints=40);

%[text] **第 2、3 小題：期望總成本（要考慮瑕疵率）**
defectRates = [0.001 0.01 0.05 0.10];
fprintf("\n%-12s %14s %16s %14s\n", "瑕疵率", "最佳門檻", "期望成本/件", "過殺率");
bestTh = zeros(numel(defectRates),1);
for k = 1:numel(defectRates)
    p = defectRates(k);
    ov = thTbl.("過殺率百分比")/100;
    es = thTbl.("漏檢率百分比")/100;
    % 每一件的期望成本
    cost = (1-p)*ov*c_overkill + p*es*c_escape;
    [minCost, iBest] = min(cost);
    bestTh(k) = thTbl.("門檻")(iBest);
    fprintf("%-12.3f %14.3f %16.3f %13.1f%%" + "\n", ...
        p, bestTh(k), minCost, 100*ov(iBest));
end
%[text] **第 5 小題：瑕疵率對最佳門檻的影響**
%[text] 在本章的合成資料上，兩個分布**完全分開**，
%[text] 所以任何中間的門檻成本都是 0——**看不出影響**。
%[text] > **這正是合成資料的侷限。**
%[text] > 這一題要在**你自己的資料**上才有意義（練習 6）。
%[text] 但公式本身說明了關鍵：
%[text] $$\text{成本} = (1-p) \cdot \text{過殺率} \cdot c_{ov} + p \cdot \text{漏檢率} \cdot c_{es}$$
%[text] **瑕疵率 $p$ 出現在兩項的權重上。**
%[text] 產線的 $p$ 通常低於 1%，所以：
%[text:table]
%[text] | | 權重 |
%[text] | --- | --- |
%[text] | 過殺項 | $(1-p) \approx 1$ **（幾乎全部的件數）** |
%[text] | 漏檢項 | $p \approx 0.01$ |
%[text:table]
%[text] **即使漏檢的單次成本貴 250 倍，過殺的總量仍可能更貴**——
%[text] 因為良品的數量是瑕疵的一百倍。
%[text] > 這和第 20 章的類別不平衡是同一件事，只是換到成本上：
%[text] > **少數類的單次代價高，但多數類的總量大。**
%[text] 所以「零漏檢」這個要求要看清楚它的代價：
%[text] 若為了零漏檢要接受 30% 的過殺，那條產線可能根本做不下去。
%%
%[text] # 解答 5：異常圖的誠實門檻
amap1 = anomalyMap(det0, baseData.Bad(:,:,:,1));
gt1 = baseData.BadMasks(:,:,1);

lo = double(min(amap1(:))); hi = double(max(amap1(:)));
ths = linspace(lo, hi, 20);
J = zeros(size(ths)); D = zeros(size(ths)); B = zeros(size(ths));
for k = 1:numel(ths)
    pred = amap1 >= ths(k);
    if ~any(pred(:)) || all(pred(:))
        J(k) = 0; D(k) = 0; B(k) = 0; continue
    end
    J(k) = jaccard(pred, gt1);
    D(k) = dice(pred, gt1);
    B(k) = bfscore(pred, gt1);
end

[bJ, iJ] = max(J); [bD, iD] = max(D); [bB, iB] = max(B);
fprintf("\n%-10s %10s %14s\n", "指標", "最佳值", "最佳門檻");
fprintf("%-10s %10.4f %14.3f\n", "Jaccard", bJ, ths(iJ));
fprintf("%-10s %10.4f %14.3f\n", "Dice", bD, ths(iD));
fprintf("%-10s %10.4f %14.3f\n", "BFscore", bB, ths(iB));
fprintf("三個指標的最佳門檻相同？%s\n", ...
    string(numel(unique([iJ iD iB])) == 1));

figure
plot(ths, J, "o-", LineWidth=1.6); hold on
plot(ths, D, "s--", LineWidth=1.6)
plot(ths, B, "^-", LineWidth=1.6); hold off
grid on; legend(["Jaccard" "Dice" "BFscore"], Location="best")
xlabel("異常圖的像素門檻"); ylabel("分數")
title("誠實的定位評估（自己選門檻）")

fprintf("\n主教材偏樂觀的做法（已知瑕疵面積）：0.604\n");
fprintf("誠實版本的最佳 Jaccard：%.3f（差 %.3f）\n", bJ, 0.604 - bJ);
%[text] 量到的結果：
%[text:table]
%[text] | 指標 | 最佳值 | 最佳門檻 |
%[text] | --- | --- | --- |
%[text] | Jaccard | 0.5098 | 21.171 |
%[text] | Dice | 0.6753 | 21.171 |
%[text] | **BFscore** | **0.1639** | 21.171 |
%[text:table]
%[text] **三個指標的最佳門檻剛好相同（21.171），但 BFscore 低得多。**
%[text] 面積類拿到 0.51／0.68，邊界類只有 **0.16**——
%[text] 因為異常圖是從下採樣的特徵放大回來的，**邊界本來就是糊的**。
%[text] > 這是第 20 章 §5「面積指標與邊界指標對不同的錯敏感」
%[text] > 在異常圖上的直接後果：**異常圖天生不適合用邊界指標評估。**
%[text] **第 3 小題：三個指標的最佳門檻是同一個嗎？**
%[text] 看上面的輸出。**Jaccard 與 Dice 一定相同**——
%[text] 它們是單調變換（第 20 章 §4）。
%[text] **BFscore 就不一定**，因為它量的是邊界而不是面積。
%[text] **第 4 小題：誠實版本差多少？**
%[text] 主教材的 0.604 用了「已知瑕疵面積」這個外部資訊，
%[text] 所以它是一個**上限**。誠實版本必然較低（或相等）。
%[text] > **這是第 17 章加分題、第 20 章練習 6 的同一個手法：
%[text] > 把「上限」與「實際」分開量，差距就是那一步的成本。**
%[text] **第 5 小題：回饋製程該用哪個指標？**
%[text] **面積類（Jaccard／Dice）**。
%[text] 回饋製程需要的是「**大概在哪個區域**」——
%[text] 工程師要知道是模具的哪一側、輸送帶的哪一段，
%[text] 而不是瑕疵的精確輪廓。
%[text] BFscore 對輪廓的要求在這個用途上是浪費的，
%[text] 而且它會因為異常圖天生模糊（下採樣後放大）而給出很低的分數。
%[text] > 反過來說，若下游是**雷射切除**或**自動修補**，
%[text] > 那就要輪廓精度，BFscore 才是對的指標。
%%
%[text] # 解答 6：接上你自己的資料
%[text] **這一題沒有標準答案**，但可以把檢查清單寫成程式碼。
%[text] 下面示範完整的流程，只要把 `Source="folder"` 那幾行取消註解即可。
%[text] ```matlab
%[text] data = ch22_loadDataset(Source="folder", ...
%[text]     GoodDir = "D:\產線\良品", ...
%[text]     BadDir  = "D:\產線\瑕疵", ...
%[text]     MaskDir = "D:\產線\瑕疵遮罩", ...   % 有的話
%[text]     ImageSize = [256 256]);
%[text] ```
fprintf("\n=== 換資料後的檢查清單 ===\n");
checks = [ ...
    "1. 分數分布圖：兩個分布重疊嗎？（§4）"
    "2. 良品訓練集有沒有被汙染？（解答 2 的留一法）"
    "3. 良品是否涵蓋所有已知的正常變異？（解答 3）"
    "4. 瑕疵在原圖上佔幾個像素？縮放後還剩幾個？（解答 1）"
    "5. 異常圖指到的是真瑕疵，還是固定的背景／邊框？"
    "6. 用你的過殺／漏檢成本與真實瑕疵率決定門檻（解答 4）"
    "7. 記錄基準線：分數分布、過殺率、漏檢率、每張秒數" ];
fprintf("  %s\n", checks);
%[text] **第 4 點最容易被跳過，而它最常揭露問題。**
%[text] 異常圖若一直指向影像邊緣或某個固定位置，
%[text] 那代表模型學到的是**拍攝條件的變異**，不是瑕疵。
%[text] 那種情況下分數看起來會很好，**但換一批影像就崩掉**。
%[text] > **這是異常偵測最常見的失敗模式，而且它在分數上看不出來。**
%[text] > 一定要**看圖**。
%%
%[text] # 加分題：異常偵測 vs 監督式分類的交叉點
%[text] 產生足夠的瑕疵樣本，讓監督式分類有東西可訓練。
bigBad = makeBadSet(baseData.ImageSize, 80, 140, 10, 7);
testGood = baseData.GoodTest;
testBad  = baseData.Bad;

% 異常偵測的基準（只用良品）
sG = scoreAll(det0, testGood); sB = scoreAll(det0, testBad);
thA = (max(sG) + min(sB))/2;
accAnom = (sum(sG < thA) + sum(sB >= thA)) / (numel(sG) + numel(sB));
fprintf("\n異常偵測（只用良品訓練）準確率 = %.4f\n", accAnom);

% 監督式：ResNet-18 特徵 + SVM，瑕疵樣本數逐步增加
net = imagePretrainedNetwork("resnet18");
if ipcvFast()
    nBadList = [2 8 32];
else
    nBadList = [2 4 8 16 32 64];
end
accSup = zeros(numel(nBadList),1);
featTest = featOf(net, cat(4, testGood, testBad));
yTest = categorical([repmat("good",size(testGood,4),1); ...
                     repmat("bad", size(testBad,4),1)]);

for k = 1:numel(nBadList)
    nB = nBadList(k);
    Xtr = cat(4, baseData.GoodTrain, bigBad(:,:,:,1:nB));
    ytr = categorical([repmat("good",size(baseData.GoodTrain,4),1); ...
                       repmat("bad", nB, 1)]);
    F = featOf(net, Xtr);
    mdl = fitcecoc(F, ytr, Learners="linear");
    accSup(k) = mean(predict(mdl, featTest) == yTest);
    fprintf("  瑕疵樣本 %2d 張：監督式準確率 %.4f\n", nB, accSup(k));
end
clear net

figure
plot(nBadList, accSup, "o-", LineWidth=1.8); hold on
yline(accAnom, "r--", "異常偵測（0 張瑕疵）", LineWidth=1.5); hold off
grid on; xlabel("監督式用到的瑕疵樣本數"); ylabel("準確率")
title("異常偵測 vs 監督式分類")

iCross = find(accSup > accAnom, 1);
if isempty(iCross)
    fprintf("\n**在掃描範圍內監督式沒有反超。**\n");
else
    fprintf("\n**監督式在 %d 張瑕疵樣本時反超。**\n", nBadList(iCross));
end
%[text] ## 量到的結果——**兩者都是滿分，看不出交叉點**
%[text:table]
%[text] | 做法 | 準確率 |
%[text] | --- | --- |
%[text] | 異常偵測（0 張瑕疵） | **1.0000** |
%[text] | 監督式（2 張瑕疵） | **1.0000** |
%[text] | 監督式（8 張） | 1.0000 |
%[text] | 監督式（32 張） | 1.0000 |
%[text:table]
%[text] **合成資料太簡單，兩條路線都撞到天花板。**
%[text] 這題問的「交叉點」在這個資料上**量不出來**——
%[text] 和第 18 章練習 1 撞到 1.0000 是同一個問題。
%[text] > **要回答這一題，必須用練習 1 調出來的困難瑕疵**
%[text] > （對比度 10 附近），或者直接用你自己的資料（練習 6）。
%[text] 不過這個「失敗」本身有一個值得記下的意義：
%[text] **當兩種方法都拿滿分時，該選的是成本低的那個**——
%[text] 而異常偵測不需要瑕疵樣本，所以它贏。
%[text] **第 6 小題：即使監督式反超了，什麼時候仍該用異常偵測？**
%[text] **① 新的瑕疵型態會不斷出現。**
%[text] 監督式分類只認得訓練過的類別。產線換模具、換供應商、
%[text] 換批次，都會帶來沒見過的瑕疵——
%[text] **監督式會把它們分類成「良品」**（因為它只有兩個選項，
%[text] 而新瑕疵不像它學過的瑕疵）。
%[text] 異常偵測則會說「這個不像我看過的良品」，
%[text] 因為它從頭到尾只學「正常」。
%[text] > 這和第 21 章「CLIP 只能在你給的選項裡挑」是同一個限制，
%[text] > 也和第 16 章「訓練分布 ≠ 推論分布」是同一件事。
%[text] **② 瑕疵樣本的收集本身有成本而且會延遲上線。**
%[text] 要等到累積 32 張某類瑕疵，可能是幾個月——
%[text] 而異常偵測第一天就能上線。
%[text] **③ 實務上兩者常常並存。**
%[text] 異常偵測當第一道（抓所有不正常的），
%[text] 監督式分類當第二道（把已知的瑕疵分類、判定嚴重程度）。
%[text] **這樣新型態不會漏掉，已知型態也能自動分流。**

% ========================================================================
function s = scoreAll(detector, imgs)
n = size(imgs,4);
s = zeros(n,1);
for k = 1:n
    s(k) = predict(detector, imgs(:,:,:,k));
end
end

% ========================================================================
function B = makeBadSet(sz, n, contrast, defectSize, seed)
%MAKEBADSET 產生可控難度的瑕疵：contrast 是亮度差、defectSize 是邊長。
rng(seed);
B = zeros(sz(1), sz(2), 3, n, "uint8");
for k = 1:n
    base = 200 + 8*randn(sz);
    I = repmat(uint8(base), 1, 1, 3);
    r = randi([6, sz(1)-defectSize-6]);
    c = randi([6, sz(2)-defectSize-6]);
    patch = uint8(max(0, 200 - contrast) + 6*randn(defectSize, defectSize));
    I(r:r+defectSize-1, c:c+defectSize-1, :) = repmat(patch, 1, 1, 3);
    B(:,:,:,k) = I;
end
end

% ========================================================================
function F = featOf(net, imgs)
%FEATOF 用 ResNet-18 的 pool5 抽特徵（第 18 章策略一）。
n = size(imgs,4);
F = zeros(n, 512);
for k = 1:n
    X = single(imresize(imgs(:,:,:,k), [224 224]));
    A = predict(net, dlarray(X, "SSCB"), Outputs="pool5");
    F(k,:) = squeeze(extractdata(A)).';
end
end

% ========================================================================
function s = ternStr(c, a, b)
if c, s = a; else, s = b; end
end

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline","rightPanelPercent":40}
%---
