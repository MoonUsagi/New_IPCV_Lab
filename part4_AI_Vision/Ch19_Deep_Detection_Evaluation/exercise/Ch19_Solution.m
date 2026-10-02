%[text] # 第 19 章　練習解答
%[text] 深度學習物件偵測與模型評估
assert(exist("ch19_runDetector","file") == 2, ...
    "請先切換到課程根目錄並執行 ipcvSetup。");
rng(0);

vd = fullfile(toolboxdir("vision"), "visiondata");
v = load("vehicleTrainingData.mat"); fn = fieldnames(v);
vehicleTbl = v.(fn{1});

if ipcvFast()
    N = 20; NSET = 3;
    disp("（快速模式：每組 20 張、3 組。完整執行 40 張、5 組。）")
else
    N = 40; NSET = 5;
end
idx = round(linspace(1, height(vehicleTbl), N));
files = fullfile(vd, string(vehicleTbl.imageFilename(idx))).';
gtBoxes = vehicleTbl.vehicle(idx);

detS = yoloxObjectDetector("small-coco");
raw = ch19_runDetector(detS, files);
detResults = ch19_mapClasses(raw, ["car" "truck" "bus"], "vehicle");
blds = boxLabelDatastore(table(gtBoxes(:), VariableNames="vehicle"));
%%
%[text] # 解答 1：類別對應的正確流程
%[text] **第 1 步：先只看類別分布，不要評估。**
[~, info1] = ch19_runDetector(detS, files(1:min(10,end)));
disp(info1.ClassCounts)
%[text] **第 2 步：依語意寫下規則與理由（在看到分數之前）。**
%[text] 我的規則與理由：
%[text:table]
%[text] | COCO 類別 | 納入？ | 理由 |
%[text] | --- | --- | --- |
%[text] | `car` | ✅ | 定義上就是 vehicle |
%[text] | `truck` | ✅ | 這批是道路場景，卡車是合理的車輛，且標註者很可能把它標成車 |
%[text] | `bus` | ✅ | 同上 |
%[text] | `motorcycle` | ❌ | 實際分布裡**一次都沒出現**，納入只是增加未來的不確定性 |
%[text] | `traffic light` / `stop sign` / `parking meter` | ❌ | 語意上不是車輛 |
%[text] | `train` / `boat` | ❌ | 語意上不是道路車輛；而且各只出現 1 次，很可能是誤判 |
%[text:table]
%[text] **第 3 步：規則寫完了，現在才評估。**
myMapping = ["car" "truck" "bus"];
drMine = ch19_mapClasses(raw, myMapping, "vehicle");
mMine = evaluateObjectDetection(drMine, blds, 0.5, Verbose=false);
fprintf("\n我的規則的 AP = %.4f\n", mMine.ClassMetrics.APOverlapAvg(1));
%%
%[text] ## 第 4、5 小題：看到別的分數更高，該不該改？
allMappings = { ...
    "car",                        "car"; ...
    "car+truck",                  ["car" "truck"]; ...
    "car+truck+bus（我的規則）",    ["car" "truck" "bus"]; ...
    "car+truck+bus+train",        ["car" "truck" "bus" "train"]; ...
    "car+truck+bus+train+boat",   ["car" "truck" "bus" "train" "boat"]; ...
    "全部都算",                    ["car" "truck" "bus" "train" "boat" ...
                                   "traffic light" "stop sign" "parking meter"] };
sweep1 = ch19_classMapping(raw, gtBoxes, allMappings, "vehicle");
disp(sweep1)
%[text] **第 4 小題：為什麼不該改？**
%[text] 因為你是**看了測試集的分數才改規則**的。
%[text] 那等於用測試集調超參數——改完之後，
%[text] 那個分數**不再是對未見資料的估計**，
%[text] 它是「在這批資料上能挑到的最好結果」。
%[text] 換一批新資料，你挑的那個規則不一定還是最好的。
%[text] > 這是第 16 章練習 3「資料洩漏」的另一個面貌：
%[text] > 洩漏不一定是影像重複，**用測試集做任何決定都是洩漏**。
%[text] 注意 `train` 與 `boat` 各只出現一次。把它們納入
%[text] 可能讓分數微幅上升，但那是**一兩個框的隨機效應**——
%[text] 第 18 章 §6.1 的雜訊分析告訴你，那種幅度的差異不可解釋。
%[text] **第 5 小題：合法修改規則的流程**
%[text] 把三件事組合起來：
%[text] 1. **切出一個「開發集」**（development set），與最終測試集分開
%[text]    （第 16 章練習 3 的留出原則）
%[text] 2. **所有的規則探索都只在開發集上做**，可以隨意掃描、隨意反悔
%[text] 3. 規則定案之後，**在測試集上跑唯一的一次**，那個數字才是可報告的
%[text] 4. 報告時要寫明「規則是在開發集上決定的」
%[text] 5. 若之後又想改規則 → **需要一批新的測試資料**
%[text] > **測試集是一次性的資源。** 每多看它一次，
%[text] > 它給出的估計就樂觀一點。
%%
%[text] # 解答 2：把 precision 拉上來
%[text] §7 顯示 83% 的誤判是背景誤判，所以先從分數門檻下手。
%[text] 另外兩種手段用 GT 的**先驗統計**過濾不合理的框。
% **注意：統計要從訓練資料算，不能用測試集。**
% 這裡用「沒有被選進評估子集」的那些影像當作訓練資料。
trainMask = true(height(vehicleTbl),1);
trainMask(idx) = false;
trainBoxes = vertcat(vehicleTbl.vehicle{trainMask});
wTrain = trainBoxes(:,3);
arTrain = trainBoxes(:,3) ./ trainBoxes(:,4);
fprintf("\n訓練資料的 GT 統計（%d 個框）：\n", size(trainBoxes,1));
fprintf("  寬度：%.0f – %.0f（1%%–99%% 分位 %.0f – %.0f）\n", ...
    min(wTrain), max(wTrain), prctile(wTrain,1), prctile(wTrain,99));
fprintf("  長寬比：%.2f – %.2f（1%%–99%% 分位 %.2f – %.2f）\n", ...
    min(arTrain), max(arTrain), prctile(arTrain,1), prctile(arTrain,99));

wLo = prctile(wTrain,1);  wHi = prctile(wTrain,99);
arLo = prctile(arTrain,1); arHi = prctile(arTrain,99);

methods = strings(0,1); P = []; R = []; F = []; NB = [];
function [p,r,f,nb] = evalDR(dr, blds, gtBoxes)
    nb = sum(cellfun(@(x) size(x,1), dr.Boxes));
    if nb == 0, p=NaN; r=0; f=0; return, end
    m = evaluateObjectDetection(dr, blds, 0.5, Verbose=false);
    pp = m.ClassMetrics.Precision{1}; rr = m.ClassMetrics.Recall{1};
    p = 100*pp(end); r = 100*rr(end);
    f = 2*p*r/max(p+r,eps);
end

[p,r,f,nb] = evalDR(detResults, blds, gtBoxes);
methods(end+1) = "基準（無過濾）"; P(end+1)=p; R(end+1)=r; F(end+1)=f; NB(end+1)=nb;

% 手段 1：分數門檻
dr1 = filterBoxes(detResults, "vehicle", @(b,s) s >= 0.6);
[p,r,f,nb] = evalDR(dr1, blds, gtBoxes);
methods(end+1) = "手段1 分數>=0.6"; P(end+1)=p; R(end+1)=r; F(end+1)=f; NB(end+1)=nb;

% 手段 2：框寬度
dr2 = filterBoxes(detResults, "vehicle", @(b,s) b(:,3) >= wLo & b(:,3) <= wHi);
[p,r,f,nb] = evalDR(dr2, blds, gtBoxes);
methods(end+1) = "手段2 寬度過濾"; P(end+1)=p; R(end+1)=r; F(end+1)=f; NB(end+1)=nb;

% 手段 3：長寬比
dr3 = filterBoxes(detResults, "vehicle", ...
    @(b,s) (b(:,3)./b(:,4)) >= arLo & (b(:,3)./b(:,4)) <= arHi);
[p,r,f,nb] = evalDR(dr3, blds, gtBoxes);
methods(end+1) = "手段3 長寬比過濾"; P(end+1)=p; R(end+1)=r; F(end+1)=f; NB(end+1)=nb;

% 三種一起
dr4 = filterBoxes(detResults, "vehicle", @(b,s) s >= 0.6 & ...
    b(:,3) >= wLo & b(:,3) <= wHi & ...
    (b(:,3)./b(:,4)) >= arLo & (b(:,3)./b(:,4)) <= arHi);
[p,r,f,nb] = evalDR(dr4, blds, gtBoxes);
methods(end+1) = "三種一起"; P(end+1)=p; R(end+1)=r; F(end+1)=f; NB(end+1)=nb;

resTbl = table(methods(:), NB(:), P(:), R(:), F(:), ...
    VariableNames=["手段" "框數" "precision" "recall" "F1"]);
disp(resTbl)

base = 1;
fprintf("\n%-20s %14s %14s %12s\n", "手段", "precision 提升", "recall 損失", "比值");
for k = 2:numel(methods)
    dP = P(k)-P(base); dR = R(base)-R(k);
    fprintf("%-20s %13.1f%% %13.1f%% %12s\n", methods(k), dP, dR, ...
        string(round(dP/max(dR,0.1),2)));
end
%[text] 量到的結果（快速模式 20 張）：
%[text:table]
%[text] | 手段 | 框數 | precision | recall | F1 |
%[text] | --- | --- | --- | --- | --- |
%[text] | 基準（無過濾） | 82 | 22.0% | 81.8% | 34.6 |
%[text] | 手段1 分數≥0.6 | 38 | 42.1% | 72.7% | 53.3 |
%[text] | 手段2 寬度過濾 | 54 | 33.3% | 81.8% | 47.4 |
%[text] | 手段3 長寬比過濾 | 56 | 33.9% | **86.4%** | 48.7 |
%[text] | **三種一起** | 24 | **62.5%** | 68.2% | **65.2** |
%[text] | 手段 | precision 提升 | recall 損失 | 比值 |
%[text] | --- | --- | --- | --- |
%[text] | 手段1 分數≥0.6 | +20.2% | 9.1% | 2.22 |
%[text] | 手段2 寬度過濾 | +11.4% | **0.0%** | **113.8** |
%[text] | 手段3 長寬比過濾 | +12.0% | **−4.5%** | **119.8** |
%[text] | 三種一起 | +40.5% | 13.6% | 2.97 |
%[text:table]
%[text] **第 5 小題：哪一種手段的比值最好？**
%[text] **幾何過濾（手段 2、3）的比值高出兩個數量級**，
%[text] 因為它們幾乎不損失 recall——被濾掉的框本來就不是車。
%[text] **手段 3 的 recall 反而上升了 4.5 個百分點**（81.8% → 86.4%）。
%[text] 這不是誤差：長寬比不合理的框原本會**搶走配對**
%[text] （它和某個 GT 的 IoU 剛好過門檻，卻排在真正的好框前面），
%[text] 濾掉它們之後，好框才配得上。
%[text] > **過濾掉壞框可以同時提升 precision 和 recall。**
%[text] > 這打破了「precision 與 recall 必然此消彼長」的直覺——
%[text] > 那個取捨只在「調同一個分數門檻」時才成立。
%[text] 而「三種一起」把 F1 從 34.6 拉到 **65.2，將近翻倍**。
%[text] 分數門檻的比值最差（2.22），因為它是**不分青紅皂白**地砍，
%[text] 會連帶砍掉低分但正確的框。
%[text] **注意「寬度過濾」與「長寬比過濾」用的是訓練資料的分位數**，
%[text] 不是測試資料的。這一點很重要：
%[text] 用測試集的統計去過濾測試集的預測，是把答案偷渡進方法裡。
%[text] > **先驗知識（訓練資料的統計）可以用，
%[text] > 測試資料的統計不行——即使那個統計看起來「很一般」。**
%%
%[text] # 解答 3：比較兩個偵測器（配對比較 + 雜訊分析）
%[text] 用多批不同的影像子集重複評估，再做配對比較。
models = ["tiny-coco" "small-coco"];
apMat = nan(NSET, numel(models));
secMat = nan(NSET, numel(models));

for m = 1:numel(models)
    dm = yoloxObjectDetector(models(m));
    for s = 1:NSET
        rng(200 + s);
        pick = randperm(height(vehicleTbl), N);
        fs = fullfile(vd, string(vehicleTbl.imageFilename(pick))).';
        gs = vehicleTbl.vehicle(pick);
        [rw, inf2] = ch19_runDetector(dm, fs);
        d = ch19_mapClasses(rw, ["car" "truck" "bus"], "vehicle");
        bl = boxLabelDatastore(table(gs(:), VariableNames="vehicle"));
        mm = evaluateObjectDetection(d, bl, 0.5, Verbose=false);
        apMat(s,m) = mm.ClassMetrics.APOverlapAvg(1);
        secMat(s,m) = inf2.SecPerImage;
    end
    clear dm      % 第 17 章 §10.1：用完釋放
    fprintf("  %s 完成\n", models(m));
end

fprintf("\n%-14s %10s %10s %12s\n", "模型", "AP 平均", "AP 標準差", "秒/張");
for m = 1:numel(models)
    fprintf("%-14s %10.4f %10.4f %12.4f\n", models(m), ...
        mean(apMat(:,m)), std(apMat(:,m)), mean(secMat(:,m)));
end

d = apMat(:,2) - apMat(:,1);      % small - tiny
df = numel(d) - 1;
seD = std(d)/sqrt(numel(d));
tStat = mean(d)/max(seD, eps);
tCrit = tinv(0.975, df);
pVal = 2*(1 - tcdf(abs(tStat), df));
fprintf("\n配對差值（small - tiny）：平均 %.4f、SD %.4f\n", mean(d), std(d));
fprintf("t = %.2f、自由度 %d、臨界 t = %.2f、p = %.3f → 有差異？%s\n", ...
    tStat, df, tCrit, pVal, string(pVal < 0.05));
%[text] 量到的結果（3 組各 20 張）：
%[text:table]
%[text] | 模型 | AP 平均 | AP 標準差 | 秒/張 |
%[text] | --- | --- | --- | --- |
%[text] | `tiny-coco` | 0.5262 | 0.0479 | **0.0352** |
%[text] | `small-coco` | **0.6191** | 0.0264 | 0.0433 |
%[text:table]
%[text] 配對差值（small − tiny）：平均 **+0.0929**、SD 0.0742
%[text] → **t = 2.17，自由度 2，臨界 t = 4.30，p = 0.163 → 分辨不出。**
%[text] **第 4、5 小題**
%[text] 看 `p` 值。**臨界值一定要用 `tinv(0.975, df)` 算**——
%[text] 樣本少的時候它比直覺高很多（第 18 章練習 2 我在這裡犯過錯：
%[text] 自由度 2 的臨界值是 4.30，不是 2.5）。
%[text] **若分辨不出差異，那就選快的那個。**
%[text] 這不是妥協，是正確的決策：
%[text] 在「效能沒有可測量的差異」的前提下，
%[text] **速度、記憶體、部署難度都是實打實的優勢**。
%[text] > **「沒有證據顯示 A 比 B 好」時，
%[text] > 該用其他準則選，而不是硬挑一個分數高的。**
%%
%[text] # 解答 4：COCO 風格的 mAP
cocoTh = 0.5:0.05:0.95;
apCoco = zeros(numel(cocoTh),1);
for k = 1:numel(cocoTh)
    mk = evaluateObjectDetection(detResults, blds, cocoTh(k), Verbose=false);
    apCoco(k) = mk.ClassMetrics.APOverlapAvg(1);
end
mAPcoco = mean(apCoco);
m50 = evaluateObjectDetection(detResults, blds, 0.50, Verbose=false);
m75 = evaluateObjectDetection(detResults, blds, 0.75, Verbose=false);

fprintf("\nmAP@0.5              = %.4f\n", m50.ClassMetrics.APOverlapAvg(1));
fprintf("mAP@0.75             = %.4f\n", m75.ClassMetrics.APOverlapAvg(1));
fprintf("mAP@[0.5:0.05:0.95]  = %.4f\n", mAPcoco);
fprintf("mAP@0.5 是 COCO 風格的 %.2f 倍\n", ...
    m50.ClassMetrics.APOverlapAvg(1)/max(mAPcoco,eps));

figure
plot(cocoTh, apCoco, "o-", LineWidth=2, MarkerSize=7); grid on
xlabel("IoU 門檻"); ylabel("AP"); title("AP vs IoU 門檻（COCO 的十個門檻）")
%[text] 量到的結果：
%[text:table]
%[text] | 指標 | 值 |
%[text] | --- | --- |
%[text] | mAP@0.5 | 0.5602 |
%[text] | mAP@0.75 | **0.5602**（和 @0.5 完全一樣） |
%[text] | mAP@[0.5:0.05:0.95] | **0.4430** |
%[text:table]
%[text] **mAP@0.5 是 COCO 風格的 1.26 倍。**
%[text] 而 **mAP@0.75 和 mAP@0.5 一模一樣**——
%[text] 這是主教材 §5「0.3 到 0.6 完全平坦」的延伸，
%[text] 在這批資料上平坦區甚至延伸到 0.75。
%[text] **第 3 小題：用 IoU 分布解釋差距**
%[text] 主教材 §5 量到 IoU 分布是**雙峰**的：
%[text] 命中框平均 0.871，誤判框中位數 0.010。
%[text] 所以 AP 在 0.5–0.85 之間幾乎不變（那些框都穩穩超過門檻），
%[text] 到 0.9 才崩潰（0.871 的平均值開始不夠用）。
%[text] COCO 風格取十個門檻的平均，其中 **0.9 與 0.95 兩個門檻**
%[text] 把平均值拉低。
%[text] **第 5 小題：哪一個指標最適合？**
%[text] 這題要論證，不是背誦。兩邊都有道理：
%[text:table]
%[text] | 主張 | 論點 |
%[text] | --- | --- |
%[text] | 用 mAP@0.5 | 這批目標小（中位數 68 像素寬），0.9 的 IoU 要求在這個尺度上過苛——幾個像素的誤差就會掉到 0.9 以下 |
%[text] | 用 COCO 風格 | 它反映定位精度，而定位精度在某些應用（機器手臂抓取）確實關鍵 |
%[text:table]
%[text] **判準是下游任務**：
%[text] - 只要知道「有沒有車、大概在哪」→ mAP@0.5 就夠
%[text] - 要用框去做精確的幾何量測 → 必須看高 IoU 的表現
%[text] > **不要因為「COCO 都這樣報」就照抄。**
%[text] > 指標要配合任務，這是第 11、12、15、16 章反覆出現的同一件事。
%%
%[text] # 解答 5：小目標問題
areaGT = []; detected = [];
for i = 1:numel(gtBoxes)
    g = gtBoxes{i};
    b = detResults.Boxes{i};
    for j = 1:size(g,1)
        areaGT(end+1) = g(j,3)*g(j,4); %#ok<AGROW>
        if isempty(b)
            detected(end+1) = 0; %#ok<AGROW>
        else
            detected(end+1) = double(max(bboxOverlapRatio(b, g(j,:))) >= 0.5); %#ok<AGROW>
        end
    end
end
areaGT = areaGT(:); detected = detected(:);

edges = prctile(areaGT, [0 33 67 100]);
edges(1) = edges(1) - 1;
grp = discretize(areaGT, edges);
names = ["小" "中" "大"];
fprintf("\n%-6s %12s %10s %10s\n", "組別", "面積範圍", "數量", "偵測率");
for k = 1:3
    sel = grp == k;
    fprintf("%-6s %5.0f–%-6.0f %10d %9.1f%%" + "\n", names(k), ...
        min(areaGT(sel)), max(areaGT(sel)), nnz(sel), 100*mean(detected(sel)));
end

figure
boxchart(categorical(names(grp)'), areaGT, GroupByColor=categorical(detected));
ylabel("GT 框面積（像素²）"); legend(["沒偵測到" "偵測到"], Location="best")
title("目標面積 vs 有沒有被偵測到")
%[text] ## 量到的結果——**和題目的預期相反**
%[text:table]
%[text] | 組別 | 面積範圍（像素²） | 數量 | 偵測率 |
%[text] | --- | --- | --- | --- |
%[text] | 小 | 320–864 | 7 | **100.0%** |
%[text] | 中 | 1,470–8,640 | 8 | **100.0%** |
%[text] | 大 | 9,202–11,070 | 7 | **85.7%** |
%[text:table]
%[text] **最大的目標偵測率最低，小目標反而全中。**
%[text] 題目問的是「偵測率開始下降的尺寸」，預設了
%[text] 「小目標比較難」——**這批資料上不成立**。
%[text] 為什麼？因為**這批影像是車輛的特寫裁切**（128×228），
%[text] 「大目標」指的是**幾乎填滿整個畫面**的車。那種情況下：
%[text] - 車子被畫面邊界**切掉**，只看得到一部分
%[text] - 缺乏周圍的**場景脈絡**（路面、其他車），
%[text]   而 COCO 訓練出來的模型很依賴脈絡
%[text] - 偵測器可能把它拆成好幾個部分框，沒有一個達到 IoU 0.5
%[text] > **「小目標比較難」是一個關於完整場景照片的通則，
%[text] > 而它在裁切圖上反過來。**
%[text] > 這一題真正的教訓是：**先量，再套用通則。**
%[text] 注意樣本數只有 7–8 個，第 18 章 §6.1 的雜訊問題在這裡更嚴重
%[text] （一個目標就值 14 個百分點）。所以正確的說法是
%[text] 「**沒有證據支持小目標比較難**」，而不是「大目標比較難」。
%[text] **第 5 小題（原本的問題仍然值得回答）**
%[text] 在**完整場景照片**上，偵測率確實會隨目標變小而下降，
%[text] 而那個門檻和輸入解析度直接相關。
%[text] 偵測器內部會把影像縮放到固定的輸入尺寸；
%[text] 一個在原圖上 20 像素寬的目標，縮放後可能只剩幾個像素，
%[text] 而卷積骨幹經過多次下採樣之後，**那個目標在最深的特徵圖上
%[text] 不到一個格子**——它的資訊已經消失了。
%[text] 要偵測更小的目標，三個做法與各自的代價：
%[text:table]
%[text] | 做法 | 代價 |
%[text] | --- | --- |
%[text] | **提高輸入解析度** | 記憶體與時間**平方成長** |
%[text] | **影像切塊分別偵測** | 跨塊的目標會被切斷，而且要處理重疊與合併 |
%[text] | **換為小目標設計的模型** | 通常犧牲大目標的表現或速度 |
%[text:table]
%[text] > 這是第 16 章 §8「滑動視窗沒有規模經濟」的深度學習版本：
%[text] > **解析度的成本永遠是平方的。**
%%
%[text] # 解答 6：訓練的程式碼與擴增檢查（不執行）
%[text] > **本題不執行訓練**（開發機器記憶體不足）。
%[text] > 但**第 2 點的擴增檢查不需要訓練就能做**，而且必須做。
allFiles = fullfile(vd, string(vehicleTbl.imageFilename));
imdsAll = imageDatastore(allFiles);
bldsAll = boxLabelDatastore(vehicleTbl(:, "vehicle"));
dsAll = combine(imdsAll, bldsAll);

% 加上擴增：影像與框**同步**變換
dsAug = transform(dsAll, @(data) augmentDetection(data));

%[text] ## 擴增檢查：框還在物體上嗎？
%[text] 這是第 17 章 §5 質心檢查的偵測版。
%[text] **判準**：框內的平均亮度應該和原本框內的相近
%[text] （車是暗的、背景是亮的，框跑掉就會變亮）。
reset(dsAll); reset(dsAug);
diffs = zeros(12,1);
for k = 1:12
    a = read(dsAll);
    b = read(dsAug);
    diffs(k) = abs(boxMeanIntensity(a{1}, a{2}) - boxMeanIntensity(b{1}, b{2}));
end
fprintf("\n擴增前後「框內平均亮度」的差：中位數 %.2f、最大 %.2f（0–255）\n", ...
    median(diffs), max(diffs));
if max(diffs) < 25
    fprintf("**框跟著影像一起變換了。**\n");
else
    fprintf("**警告：框可能沒有跟上影像的變換。**\n");
end

[detTrain, infoTrain] = ch19_trainDetector(dsAug, dsAll, "vehicle", ...
    DoTrain=false, ModelName="tiny-coco", InputSize=[320 320 3], ...
    MaxEpochs=10, MiniBatchSize=4);
clear detTrain
%[text] **第 4 小題：為什麼選那個 `InputSize`**
%[text] GT 框寬度是 16–129 像素、中位數 68，而原圖是 128×228。
%[text] 若輸入設成 320×320，影像會被**放大**（228 → 320），
%[text] 目標也跟著變大——這對小目標是好事。
%[text] 若設成 640×640 會更好，但記憶體是平方成長，而本機跑不動。
%[text] > **輸入尺寸不是越大越好，是要讓最小的目標
%[text] > 在最深的特徵圖上還佔得到格子。**
%[text] **第 5 小題：換機器後要驗證的清單**
%[text] 1. `trainYOLOXObjectDetector` 能不能跑完（記憶體、API 相容性）
%[text] 2. 訓練曲線有沒有收斂（第 18 章 §10 的四種形狀）
%[text] 3. 訓練後的 AP vs 預訓練 COCO 模型的 AP（**這是重點**）
%[text] 4. 訓練後還會不會輸出 `traffic light` 之類的東西
%[text]    （自訓模型只有一個類別，所以 §8 的「模型與標註不一致」
%[text]    問題應該消失——**這個預測要驗證**）
%[text] 5. 每張推論時間有沒有變（tiny vs small 的骨幹差異）
%%
%[text] # 加分題：評估流程的敏感度分析
%[text] 基準設定：car+truck+bus、IoU 0.5、分數門檻 0、官方配對。
baseAP = m50.ClassMetrics.APOverlapAvg(1);
fprintf("\n基準 AP = %.4f\n", baseAP);

% 決定 1：類別對應
apMap = sweep1.AP;
% 決定 2：IoU 門檻（用常見的合理範圍 0.5–0.75，不含極端的 0.9）
apIoU = zeros(3,1);
ths = [0.5 0.6 0.75];
for k = 1:3
    mk = evaluateObjectDetection(detResults, blds, ths(k), Verbose=false);
    apIoU(k) = mk.ClassMetrics.APOverlapAvg(1);
end
% 決定 3：分數門檻
apScore = zeros(4,1);
scs = [0 0.3 0.5 0.7];
for k = 1:4
    dk = filterBoxes(detResults, "vehicle", @(b,s) s >= scs(k));
    if sum(cellfun(@(x) size(x,1), dk.Boxes)) == 0
        apScore(k) = 0; continue
    end
    mk = evaluateObjectDetection(dk, blds, 0.5, Verbose=false);
    apScore(k) = mk.ClassMetrics.APOverlapAvg(1);
end

decisions = ["類別對應"; "IoU 門檻(0.5–0.75)"; "分數門檻(0–0.7)"];
lo = [min(apMap); min(apIoU); min(apScore)];
hi = [max(apMap); max(apIoU); max(apScore)];
span = hi - lo;
[span, ord] = sort(span, "descend");
decisions = decisions(ord); lo = lo(ord); hi = hi(ord);

fprintf("\n%-24s %10s %10s %10s\n", "決定", "最低 AP", "最高 AP", "影響幅度");
for k = 1:numel(decisions)
    fprintf("%-24s %10.4f %10.4f %10.4f\n", decisions(k), lo(k), hi(k), span(k));
end

figure
barh(categorical(decisions, flipud(decisions)), span)
xlabel("AP 的變化幅度"); title("龍捲風圖：每個決定值多少分")
grid on
%[text] 量到的結果（快速模式）：
%[text:table]
%[text] | 決定 | 最低 AP | 最高 AP | 影響幅度 |
%[text] | --- | --- | --- | --- |
%[text] | **類別對應** | 0.4716 | 0.5602 | **0.0886** |
%[text] | 分數門檻（0–0.7） | 0.4897 | 0.5602 | 0.0705 |
%[text] | IoU 門檻（0.5–0.75） | 0.5602 | 0.5602 | **0.0000** |
%[text:table]
%[text] **第 4 小題：哪一個決定影響最大？**
%[text] **類別對應**，而且它在兩次不同的設定下都是第一名
%[text] （主教材 40 張時影響 0.2217，這裡 20 張時 0.0886）。
%[text] IoU 門檻在 0.5–0.75 的合理範圍內**完全沒有影響**——
%[text] 這是那個雙峰分布的直接後果。
%[text] 但注意：**若把範圍放寬到 0.9，它會變成影響最大的一個**
%[text] （主教材 §5：AP 從 0.483 掉到 0.031）。
%[text] 所以「哪個決定最重要」本身也取決於你認為哪些設定值是合理的。
%[text] **第 5 小題：一份只寫「mAP = 0.48」的報告能重現嗎？**
%[text] **不能。** 必須一起寫出來的最小清單：
%[text:table]
%[text] | 欄位 | 為什麼 |
%[text] | --- | --- |
%[text] | **類別對應規則** | 本章量到它值 85% 的相對 AP |
%[text] | **IoU 門檻（以及是單一門檻還是 COCO 平均）** | 0.5 與 COCO 風格差很多 |
%[text] | **分數門檻** | AP 本身與門檻無關，但 precision／recall 完全取決於它 |
%[text] | **配對／評估程式碼的版本** | §7.1 量到兩種實作差 7 個目標 |
%[text] | **測試集的組成與大小** | 第 18 章 §6.1：n 決定了可分辨的最小差異 |
%[text] | **重複次數與變異** | 跑一次的排名不可信 |
%[text:table]
%[text] > **這份清單比任何一個 mAP 數字都有用。**
%[text] > 它也是你收到別人的分數時，該問的問題。

% ========================================================================
function dr = filterBoxes(detResults, targetName, keepFcn)
%FILTERBOXES 用一個自訂條件過濾偵測框。KEEPFCN(boxes, scores) 回傳邏輯索引。
n = height(detResults);
Boxes = cell(n,1); Scores = cell(n,1); Labels = cell(n,1);
for i = 1:n
    b = detResults.Boxes{i};
    s = detResults.Scores{i};
    if isempty(b)
        Boxes{i} = zeros(0,4); Scores{i} = zeros(0,1);
        Labels{i} = categorical(strings(0,1), targetName);
        continue
    end
    keep = keepFcn(b, s);
    Boxes{i}  = b(keep,:);
    Scores{i} = s(keep);
    Labels{i} = repmat(categorical(targetName, targetName), nnz(keep), 1);
end
dr = table(Boxes, Scores, Labels);
end

% ========================================================================
function out = augmentDetection(data)
%AUGMENTDETECTION 影像與框**同步**變換的擴增。
%
%   翻轉影像時框的 x 座標必須鏡射。寫錯不會報錯，
%   只會讓模型學不起來——所以一定要有 Solution 6 的檢查。
I = data{1};
bboxes = data{2};
labels = data{3};

if rand > 0.5
    I = fliplr(I);
    if ~isempty(bboxes)
        % [x y w h]：鏡射之後新的 x = 寬 - (舊 x + w)
        bboxes(:,1) = size(I,2) - (bboxes(:,1) + bboxes(:,3));
    end
end

out = {I, bboxes, labels};
end

% ========================================================================
function m = boxMeanIntensity(I, bboxes)
%BOXMEANINTENSITY 框內的平均亮度（用來檢查框有沒有跟著影像變換）。
if isempty(bboxes)
    m = NaN; return
end
G = im2gray(I);
b = round(bboxes(1,:));
r1 = max(1, b(2)); c1 = max(1, b(1));
r2 = min(size(G,1), b(2)+b(4)-1);
c2 = min(size(G,2), b(1)+b(3)-1);
if r2 < r1 || c2 < c1
    m = NaN; return
end
m = mean(double(G(r1:r2, c1:c2)), "all");
end

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline","rightPanelPercent":40}
%---
