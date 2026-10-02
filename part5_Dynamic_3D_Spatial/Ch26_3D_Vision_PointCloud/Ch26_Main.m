%[text] # 第 26 章　3D 視覺、點雲與場景重建
%[text] {"align":"left"}IPCV\_Lab 課程教材　｜　MATLAB R2026b　｜　難度：\[進階\]　｜　建議時數：4 小時
%[text] ## 學習目標
%[text] 讀完本章並完成練習後，你應該能夠：
%[text] 1. 跑完「校正 → 視差 → 深度 → 點雲」，並說出**每一步損失了什麼**
%[text] 2. 知道立體視覺給的**不是**稠密深度圖，以及沒有深度的三類原因
%[text] 3. **說出 MSAC 與最小平方各自為什麼存在**，並用正確的組合
%[text] 4. 量出 ICP 的收斂範圍，並知道**初始猜測值多少**
%[text] 5. 比較三種配準法的「收斂範圍 vs 精度下限」取捨
%[text] 6. 說出 SfM、SLAM、NeRF 各自解決哪一段問題
%[text] ## 前置知識
%[text] 第 25 章（標定、立體參數、基線）、第 14 章（特徵比對）。
%[text] ## 環境需求
%[text] Computer Vision Toolbox。第 11 節的 NeRF 需要
%[text] Deep Learning Toolbox 與 GPU（**本章不執行訓練**）。
assert(exist("ch26_stereoDepth", "file") == 2, ...
    "請先切換到課程根目錄並執行 ipcvSetup。");
rng(0);
%%
%[text] # 1. 這一章的位置：從 2D 到 3D
%[text] 第 25 章把像素變成了公釐——**但只在一個已知的平面上**。
%[text] 要知道「那個東西離我多遠」，單張影像永遠解不出來：
%[text] 一個大而遠的物體和一個小而近的物體，**投影完全一樣**。
%[text:table]
%[text] | 取得深度的方法 | 需要 | 本章 |
%[text] | --- | --- | --- |
%[text] | **立體視覺** | 兩台標定好的相機 | §2–§4 |
%[text] | 結構光／ToF | 主動式感測器 | 不涵蓋 |
%[text] | **Structure from Motion** | 一台相機 + 移動 | §10 |
%[text] | **SLAM** | 一台相機 + 即時 | §10 |
%[text] | **NeRF** | 多視角影像 + 訓練 | §11（未執行） |
%[text:table]
%%
%[text] # 2. 立體視覺的完整流程
[ptCloud, rep] = ch26_stereoDepth();
fprintf("校正後影像 %dx%d\n", rep.ImageSize(2), rep.ImageSize(1));
fprintf("耗時：校正 %.2f｜視差 %.2f｜重建 %.2f 秒\n", ...
    rep.SecondsRectify, rep.SecondsDisparity, rep.SecondsReconstruct);
fprintf("點雲 %d 點\n", rep.NumPoints);
%[text] 四個步驟，每一個都有它自己的失敗方式：
%[text:table]
%[text] | 步驟 | 函式 | 失敗時 |
%[text] | --- | --- | --- |
%[text] | ① 校正 | `rectifyStereoImages` | 標定不準 → 對應點不在同一條掃描線上 |
%[text] | ② 視差 | `disparitySGM` | 紋理不足／遮擋 → **`NaN`** |
%[text] | ③ 重建 | `reconstructScene` | 視差接近 0 → **深度趨近無限大** |
%[text] | ④ 點雲 | `pointCloud` | 沒過濾 → 遠處的垃圾點撐爆視野 |
%[text:table]
figure;
tiledlayout(1,2, TileSpacing="compact");
nexttile; imshow(rep.RectifiedLeft); title("校正後的左影像")
nexttile; imshow(rep.DisparityMap, [0 64]); colormap(gca, jet); colorbar
title("視差圖（白色 = NaN）")
%%
%[text] # 3. **一半的像素沒有深度**
fprintf("有視差的像素：**%.1f%%**\n", rep.ValidDisparityPct);
fprintf("深度落在 0.3–10 公尺的：**%.1f%%**\n", rep.PlausiblePct);
fprintf("有效點 %d / 總像素 %d\n", rep.NumValidPoints, rep.NumPoints);
%[text] **立體視覺給你的不是一張稠密的深度圖。**
%[text] 沒有視差的地方有三類：
%[text:table]
%[text] | 原因 | 典型位置 | 能改善嗎 |
%[text] | --- | --- | --- |
%[text] | **紋理不足** | 白牆、天空、單色物體 | 打投影紋理（結構光的概念） |
%[text] | **遮擋** | 只有一台相機看得到的區域 | **不能**，那是幾何上的必然 |
%[text] | 超出視差範圍 | 太近或太遠 | 調 `DisparityRange` |
%[text:table]
%[text] > **`disparitySGM` 對這些像素回傳 `NaN`，不是 0。**
%[text] > 把 `NaN` 當成 0 會在原點附近堆出一團**假點**，
%[text] > 而且 `pcshow` 不會抱怨——它只會安靜地畫出來。
%[text] ## 放大搜尋範圍不會讓有效率變高
ranges = {[0 32], [0 64], [0 128], [16 80]};
RangeStr = strings(4,1);
ValidPct = zeros(4,1);
PlausPct = zeros(4,1);
ZMed     = zeros(4,1);
for i = 1:4
    [~, r] = ch26_stereoDepth(DisparityRange=ranges{i});
    RangeStr(i) = mat2str(ranges{i});
    ValidPct(i) = r.ValidDisparityPct;
    PlausPct(i) = r.PlausiblePct;
    ZMed(i)     = r.ZMedian;
end
disp(table(RangeStr, ValidPct, PlausPct, ZMed, ...
    VariableNames=["視差範圍" "有視差%" "合理深度%" "Z中位數m"]))
%[text:table]
%[text] | 視差範圍 | 有視差 | 合理深度 |
%[text] | --- | --- | --- |
%[text] | `[0 32]` | **58.5%** | **55.2%** |
%[text] | `[0 64]` | 52.7% | 51.0% |
%[text] | `[0 128]` | **47.9%** | **47.7%** |
%[text:table]
%[text] **範圍越大，有效率越低。** 這和直覺相反。
%[text] 原因是**搜尋範圍越大，錯誤的匹配機會越多**；
%[text] SGM 的一致性檢查把那些模稜兩可的結果丟掉，於是有效率下降。
%[text] > **`DisparityRange` 不是「開大一點比較保險」的參數。**
%[text] > 它要**從你的工作距離算出來**：
%[text] > $d = fB/Z$，把最近與最遠的工作距離代進去就是範圍。
%[text] > 這正是第 25 章練習 5 的公式。
%%
%[text] # 4. 深度誤差在遠處爆炸
fprintf("過濾後的深度：%.2f – %.2f 公尺（中位數 %.2f）\n", ...
    rep.ZMin, rep.ZMax, rep.ZMedian);
fprintf("**沒過濾的話，最遠會算到 %.1f 公尺**\n", rep.ZMaxRaw);
%[text] **118.6 公尺**——用一對 640×480、基線 121 mm 的相機。
%[text] 那顯然是垃圾，但**程式不會告訴你**。
%[text] 第 25 章練習 5 推導過：
%[text] $$Z = \frac{fB}{d} \qquad \delta Z = \frac{Z^2}{fB}\,\delta d$$
%[text] **深度誤差正比於 $Z^2$。** 視差只要差半個像素，
%[text] 10 公尺處的深度就差了幾公尺。視差接近 0 時，$Z$ 直接發散。
stereoData = load(fullfile(toolboxdir("vision"), "visiondata", ...
    "handshakeStereoParams.mat"));
% **要拆成中間變數。** `sp.CameraParameters1.Intrinsics.FocalLength(1)`
% 一路點下去會報「Intermediate dot '.' indexing produced a
% comma-separated list with 0 values」——這組參數的 ImageSize 是空的，
% 使得 `.Intrinsics` 在鏈式取用時展開成空的逗號分隔列表。
sp   = stereoData.stereoParams;
cam1 = sp.CameraParameters1;
fLen = cam1.FocalLength;
fx   = fLen(1);
B    = norm(sp.PoseCamera2.Translation) / 1000;
Zq = [1 2 5 10 20]';
dq = fx * B ./ Zq;
dZ = Zq.^2 * 0.5 / (fx * B);
disp(table(Zq, dq, dZ, dZ./Zq*100, ...
    VariableNames=["距離m" "視差px" "誤差m(0.5px)" "相對誤差%"]))
%[text] > **所以「合理深度」的上限要自己設。**
%[text] > `ch26_stereoDepth` 預設砍在 10 公尺，
%[text] > 因為超過那裡的點的相對誤差已經超過 10%。
%[text] > **這個門檻應該從你的精度需求反推，不是隨便設的。**
%%
%[text] # 5. SGM vs BM
MethodName = ["SGM" "BM"]';
ValidP = zeros(2,1);
Secs   = zeros(2,1);
for i = 1:2
    [~, r] = ch26_stereoDepth(Method=MethodName(i));
    ValidP(i) = r.ValidDisparityPct;
    Secs(i)   = r.SecondsDisparity;
end
disp(table(MethodName, ValidP, Secs, VariableNames=["方法" "有視差%" "秒"]))
%[text:table]
%[text] | 方法 | 有視差 | 耗時 |
%[text] | --- | --- | --- |
%[text] | **SGM**（半全域比對） | **52.7%** | 0.045 s |
%[text] | BM（區塊比對） | 48.4% | **0.029 s** |
%[text:table]
%[text] **SGM 多 4.3 個百分點的有效率，慢 1.6 倍。**
%[text] 但只看有效率會漏掉更重要的事。**兩者在共同有效的區域上：**
%[text:table]
%[text] | 統計量 | 值 |
%[text] | --- | --- |
%[text] | 差異的**中位數** | **0.34 像素** |
%[text] | 差異的 **RMS** | **7.17 像素** |
%[text:table]
%[text] **RMS 是中位數的 21 倍。** 絕大多數像素兩者一致，
%[text] 但**少數像素差得非常離譜**——而中位數把那些完全藏起來了。
%[text] > 這和第 24 章練習 4「LK 的中位數是 0 因為 67% 的像素沒有輸出」
%[text] > 是同一類問題：**中位數對一小群極端值免疫，
%[text] > 而在深度圖上，一小群極端值就是一堆飛在空中的假點。**
%[text] **看深度圖要同時看中位數和尾巴。**
%%
%[text] # 6. 點雲處理：降採樣與去雜訊
teapot = pcread(which("teapot.ply"));   % R2026b 起檔案搬到 toolbox/shared/visionpointcloud/pcdata
fprintf("teapot.ply：%d 點\n", teapot.Count);

t0 = tic; grid5  = pcdownsample(teapot, "gridAverage", 0.05); tGrid = toc(t0);
t0 = tic; rand25 = pcdownsample(teapot, "random", 0.25);      tRand = toc(t0);
t0 = tic; denoised = pcdenoise(teapot);                       tDen  = toc(t0);

fprintf("gridAverage 0.05：%d → %d 點（%.2f 秒）\n", teapot.Count, grid5.Count, tGrid);
fprintf("random 0.25：     %d → %d 點（%.2f 秒）\n", teapot.Count, rand25.Count, tRand);
fprintf("pcdenoise：       %d → %d 點（%.2f 秒）\n", teapot.Count, denoised.Count, tDen);
%[text] **兩種降採樣的差別不只是速度：**
%[text:table]
%[text] | 方法 | 保留什麼 | 適合 |
%[text] | --- | --- | --- |
%[text] | `"random"` | **隨機**，密度分布不變 | 只想加速，不在乎幾何 |
%[text] | `"gridAverage"` | **每個體素一個平均點**，密度變均勻 | **配準、擬合**——這才是通常要的 |
%[text:table]
%[text] > **`"gridAverage"` 會把密集區稀釋、稀疏區保留**，
%[text] > 所以它同時是一個**密度正規化**的手段。
%[text] > 配準演算法對密度不均很敏感（密集區會主導誤差函數），
%[text] > 所以 §8 的配準一律先做 `gridAverage`。
figure;
tiledlayout(1,2, TileSpacing="compact");
nexttile; pcshow(teapot); title("原始 " + teapot.Count + " 點")
nexttile; pcshow(grid5);  title("gridAverage 0.05 → " + grid5.Count + " 點")
%%
%[text] # 7. 幾何擬合：**MSAC 與最小平方各自為什麼存在**
%[text] `pcfitplane` 用的是 MSAC（RANSAC 家族）。
%[text] 很多人以為它「比較好」，所以一律用它。**量一次。**
fitReport = ch26_fitCompare();
disp(fitReport)
%[text] ## 量到的結果（3000 點，雜訊 σ = 0.01，法向量角度誤差）
%[text] 同一份程式、同一台機器，**R2026a 與 R2026b 各跑一次**：
%[text:table]
%[text] | 離群點 | 最小平方 | `pcfitplane`（**R2026a**） | `pcfitplane`（**R2026b**） | MSAC + 內點精修（R2026b） |
%[text] | --- | --- | --- | --- | --- |
%[text] | **0%** | **0.018°** | 1.033° ± 0.656 | **0.028° ± 0.030** | 0.018° |
%[text] | **10%** | 5.121° | 0.848° ± 0.547 | **0.026° ± 0.021** | **0.015°** |
%[text] | **30%** | 28.377° | 0.795° ± 0.514 | **0.035° ± 0.022** | **0.027°** |
%[text:table]
%[text] **`pcfitplane` 在 R2026b 好了約 37 倍。** 原因寫在 R2026b 的版本說明裡：
%[text] 它現在會**用找到的內點再做一次 SVD 最小平方擬合**——也就是這個教材在 R2026a 時
%[text] 教你自己手寫的那一步，MathWorks 把它做進函式裡了。
%[text]
%[text] 在 R2026b 上，三件事是：
%[text] 1. **有離群點時，最小平方徹底崩潰**（30% 離群 → 28.4°）——這一點沒有變
%[text] 2. **`pcfitplane` 已經夠準**（0.03° 左右），大多數應用不需要再精修
%[text] 3. 自己精修仍然稍好（0.015–0.027° vs 0.026–0.035°），而且**結果幾乎不再隨機**
%[text] > ## **這一節在 R2026a 時的結論是「最小平方比 `pcfitplane` 好 58 倍」**
%[text] > 當時的解釋是：RANSAC 家族從隨機取樣的最小集合出發，找內點最多的模型，
%[text] > **不保證**用所有內點做最終的最小平方精修，所以答案有隨機性（± 0.5–0.7°）、沒有用滿資訊。
%[text] > 這個解釋描述的是 **R2026a 的 `pcfitplane`**。R2026b 改了實作，結論就跟著變了。
%[text] > **「某個函式比較不準」是對某個版本的量測，不是函式的本質。升級之後要重量。**
%[text] 自己精修的寫法（R2026a 需要；R2026b 可選，用來把隨機性壓到最低）：
%[text] ```matlab
%[text] [model, inlierIdx] = pcfitplane(cloud, maxDistance);  % 找內點
%[text] P = cloud.Location(inlierIdx, :);                     % 取內點
%[text] Q = P - mean(P,1); [~,~,V] = svd(Q,0); normal = V(:,3)';  % 最小平方重算
%[text] ```
%[text] **分工的觀念沒有變：MSAC 負責決定「誰是內點」，最小平方負責「算得準」**——
%[text] 差別只在 R2026b 的 `pcfitplane` 兩件事都做了。
%[text] 這個分工同樣適用於 `pcfitsphere`、`pcfitcylinder` 與第 14 章的 `estgeotform2d(..., "MSAC")`；
%[text] 它們在 R2026b 有沒有同樣的精修，**本章沒有逐一量過**。
%%
%[text] # 8. 配準：ICP 的收斂範圍只有 2 度
%[text] 配準沒有真值可看——兩朵點雲疊起來「看起來很準」，
%[text] 可能只是你從那個角度看不出來。
%[text] **所以把一朵點雲自己轉一個已知角度再配回去。**
regReport = ch26_registerCompare(Angles=[1 2 5 20], Methods="icp");
disp(regReport(:, ["Method" "TrueAngleDeg" "ResidualDeg" "RMSE" "UsedInitial" "Converged"]))
%[text] ## 量到的結果
%[text:table]
%[text] | 真實旋轉 | **沒有初始猜測** | **給正確初始猜測** |
%[text] | --- | --- | --- |
%[text] | 1.2° | **7.8e-08°** ✅ | 7.8e-08° ✅ |
%[text] | 2.5° | **2.172°** ❌ | **3.0e-07°** ✅ |
%[text] | 6.2° | **3.868°** ❌ | **3.0e-07°** ✅ |
%[text] | 24.7° | **2.437°** ❌ | **8.5e-07°** ✅ |
%[text:table]
%[text] > ## **ICP 的收斂範圍在這朵點雲上只到約 2 度。**
%[text] > 超過就卡在局部極小值。而**給一個正確的初始猜測，
%[text] > 24.7 度的變換也能配到 1e-06 度**。
%[text] **ICP 不是「找到最佳對齊」，是「從你給的起點往下滾」。**
%[text] 初始猜測從哪裡來？
%[text:table]
%[text] | 來源 | 場景 |
%[text] | --- | --- |
%[text] | 上一幀的結果 | 連續掃描（SLAM） |
%[text] | IMU／里程計 | 車載、機械手臂 |
%[text] | 粗略的特徵比對 | `pcmatchfeatures` + `estgeotform3d` |
%[text] | 機構設計值 | 固定安裝的感測器 |
%[text:table]
%[text] ## RMSE 是一個可用的診斷
%[text] 上表的 `RMSE` 隨殘差單調上升（1.5e-07 → 0.032 → 0.047），
%[text] 所以**即使沒有真值，RMSE 也能告訴你配準失敗了**。
%[text] 但它的單位是點雲的單位，**沒有一個絕對的合格門檻**——
%[text] 要和「成功案例」的 RMSE 比。
%[text] 順帶一提：**給初始猜測的 ICP 還比較快**
%[text]（0.028–0.038 秒 vs 0.058–0.124 秒），因為迭代次數少很多。
%%
%[text] # 9. 三種配準法：收斂範圍 vs 精度下限
regAll = ch26_registerCompare(Angles=[1 2 5 20], ...
    Methods=["icp" "ndt" "cpd"], WithInitial=false);
disp(regAll(:, ["Method" "TrueAngleDeg" "ResidualDeg" "Seconds" "Converged"]))
%[text] ## 量到的結果（都沒有給初始猜測）
%[text:table]
%[text] | 真實旋轉 | `pcregistericp` | `pcregisterndt` | **`pcregistercpd`** |
%[text] | --- | --- | --- | --- |
%[text] | 1.2° | **7.8e-08** ✅ | 0.816 | 0.382 ✅ |
%[text] | 2.5° | 2.172 ❌ | 2.378 ❌ | **0.496** ✅ |
%[text] | 6.2° | 3.868 ❌ | 5.317 ❌ | **0.355** ✅ |
%[text] | 24.7° | 2.437 ❌ | **27.787** ❌ | **0.671** |
%[text] | **耗時** | **0.03–0.12 s** | 0.05–0.08 s | **0.23–0.31 s** |
%[text:table]
%[text] > ## **一個很乾淨的取捨**
%[text:table]
%[text] | | 收斂範圍 | 精度下限 | 速度 |
%[text] | --- | --- | --- | --- |
%[text] | **ICP** | **窄（約 2°）** | **極好（1e-07）** | **最快** |
%[text] | NDT | 窄，且大角度時完全失控 | 中等 | 中等 |
%[text] | **CPD** | **寬（24.7° 還在 0.67°）** | **差（下限約 0.35°）** | **最慢 4–8 倍** |
%[text:table]
%[text] **CPD 從來沒有大幅失敗，也從來沒有很準。**
%[text] ICP 在它的範圍內完美，範圍外全錯。
%[text] > **實務上的組合：用 CPD（或特徵比對）做粗配準，
%[text] > 再用 ICP 精修。** 這正是「初始猜測」的來源之一，
%[text] > 而且和 §7 的「MSAC 找內點 + 最小平方精修」是**完全同一個模式**：
%[text] > **一個負責找到大致正確的區域，另一個負責在那裡算準。**
%[text] > **`pcregistercpd` 預設是非剛體配準**，回傳的是**位移場**
%[text] >（`single` 的 N×3 陣列），不是 `rigidtform3d`。
%[text] > 直接寫 `tform.R` 會報
%[text] > 「Dot indexing is not supported for variables of type single」
%[text] > ——那個訊息完全指不到「你拿到的根本不是變換物件」。
%[text] > **要剛體變換必須明確寫 `Transform="Rigid"`。**
%%
%[text] # 10. 從點雲到場景：分割、SfM、SLAM
%[text] ## 幾何分割
planeModel = pcfitplane(teapot, 0.1);
% 茶壺是一個連通的物體，所以門檻夠大時只會有一群。
% **把門檻掃一遍才看得出這個參數在做什麼。**
thresholds = [0.02 0.05 0.08 0.12 0.20]';
NumGroups  = zeros(numel(thresholds),1);
LargestPct = zeros(numel(thresholds),1);
for i = 1:numel(thresholds)
    [labels, nCl] = pcsegdist(grid5, thresholds(i));
    NumGroups(i) = nCl;
    if nCl > 0
        counts = histcounts(labels(labels > 0), 1:nCl+1);
        LargestPct(i) = max(counts) / grid5.Count * 100;
    end
end
disp(table(thresholds, NumGroups, LargestPct, ...
    VariableNames=["距離門檻" "群數" "最大群佔比%"]))
%[text] `pcsegdist` 只看**空間距離**：兩個點距離小於門檻就算同一群。
%[text] 它不看顏色、不看法向量、不看語意。
%[text] 茶壺是**一個連通的物體**，所以門檻夠大時只會有一群——
%[text] 而門檻太小時它會被切成幾百塊。
%[text] > **門檻是唯一的參數，而它同時決定了「會不會把兩個物體黏起來」
%[text] > 和「會不會把一個物體切碎」——和第 8 章的分割門檻同一個問題。**
%[text] > **而且它和 `pcdownsample` 的網格大小耦合**：
%[text] > 降採樣的網格是 0.05，所以距離門檻小於 0.05 時，
%[text] > **連原本相鄰的點都會被拆開**。兩個參數不能分開調。
%[text] ## Structure from Motion 與 SLAM
%[text:table]
%[text] | 工具 | 輸入 | 輸出 | 即時？ |
%[text] | --- | --- | --- | --- |
%[text] | `imageviewset` + `bundleAdjustment` | 一組影像 | 稀疏點雲 + 相機姿態 | ❌ 離線 |
%[text] | `monovslam` | 單相機影片 | 軌跡 + 地圖 | ✅ |
%[text] | `stereovslam` | 立體影片 | 軌跡 + 地圖（**有尺度**） | ✅ |
%[text] | `rgbdvslam` | RGB-D | 軌跡 + 稠密地圖 | ✅ |
%[text:table]
fprintf("\nSfM／SLAM 函式可用性：\n");
for f = ["imageviewset" "bundleAdjustment" "monovslam" "stereovslam" "rgbdvslam"]
    fprintf("  %-20s %s\n", f, string(exist(f) ~= 0));
end
%[text] > ## **單相機 SfM／SLAM 有一個根本限制：尺度未知。**
%[text] > 一台相機沿著一條軌跡拍，和一台相機沿著**放大十倍**的軌跡
%[text] > 拍一個放大十倍的場景，**影像序列完全一樣**。
%[text] > 所以 `monovslam` 的地圖是「相差一個未知比例」的。
%[text] > 要拿到真實尺度，必須加**立體相機**（基線已知）、
%[text] > **IMU**（重力加速度已知）、或**一個已知尺寸的物體**。
%[text] > 這和第 25 章練習 3 的「方格邊長定義了世界的單位」是同一件事。
%[text] R2026a 的 SLAM 改用 **SE3 轉換**，`monovslam` 新增了
%[text] IMU 對齊狀態、重力旋轉與尺度屬性——正是為了解決上面那個問題。
%%
%[text] # 11. NeRF：本章沒有執行的部分
fprintf("nerfacto 存在：%s\n", string(exist("nerfacto") ~= 0));
fprintf("trainNerfacto 存在：%s\n", string(exist("trainNerfacto") ~= 0));
%[text] `nerfacto`（R2026a 新增）用神經網路把場景表示成一個
%[text] **連續的輻射場**：給一個三維位置和一個視線方向，
%[text] 網路吐出那個方向上的顏色與密度。
%[text:table]
%[text] | | 傳統點雲重建 | **NeRF** |
%[text] | --- | --- | --- |
%[text] | 表示 | 離散的點 | **連續的函數** |
%[text] | 空洞 | 有（§3 的 49%） | **沒有**（函數處處有定義） |
%[text] | 新視角 | 只能看已有的點 | **可以合成沒拍過的視角** |
%[text] | 取得 | 幾秒 | **訓練數十分鐘到數小時** |
%[text] | 需要 | 兩台相機 | **多視角影像 + 精確的相機姿態** |
%[text:table]
%[text] > ## **NeRF 的輸入需求常被低估**
%[text] > 它需要**每張影像的精確相機姿態**——而那通常來自 SfM。
%[text] > **所以 NeRF 不是取代 SfM，是接在 SfM 後面。**
%[text] > SfM 的姿態不準，NeRF 就糊掉。
%[text] **本章不執行 NeRF 訓練**：開發機器（NVIDIA T550，4.29 GB）
%[text] 跑不動，而且沒有適合的多視角資料集。
%[text] `code/ch26_nerfSketch.m` 提供程式碼骨架並標明未驗證。
ch26_nerfSketch();
%%
%[text] # 12. 常見陷阱
%[text:table]
%[text] | 陷阱 | 症狀 | 處理 |
%[text] | --- | --- | --- |
%[text] | 把 `NaN` 視差當成 0 | 原點附近一團假點，**不報錯** | 保留 `NaN`，或明確過濾 |
%[text] | 不設深度上限 | 算出 118 公尺的點 | 從精度需求反推上限 |
%[text] | `DisparityRange` 開很大 | **有效率反而下降** | 從工作距離用 $d=fB/Z$ 算 |
%[text] | 只看視差圖的中位數 | 看不到 RMS 大 21 倍的離群 | **同時看尾巴** |
%[text] | 沿用舊版本的量測結論 | R2026a 的 `pcfitplane` 在乾淨資料上差 58 倍；R2026b 只差約 1.5 倍 | **升級後重量**；需要最準時仍可 MSAC 找內點 + 最小平方精修 |
%[text] | 沒注意 `pcfitplane` 是隨機的 | 兩次執行結果不同 | 固定 `rng`，或用精修壓掉 |
%[text] | 寫死 `toolboxdir("vision")/visiondata/teapot.ply` | R2026b 找不到檔案（搬到 Point Cloud 的資料夾） | 用 `which("teapot.ply")` |
%[text] | ICP 不給初始猜測 | 超過 2 度就卡住 | 粗配準（CPD／特徵）再精修 |
%[text] | `pcregistercpd` 當成回傳變換 | 「Dot indexing ... type single」 | **預設是非剛體**，要 `Transform="Rigid"` |
%[text] | `pcdownsample` 用 `"random"` 做配準前處理 | 密度不均會主導誤差函數 | 用 `"gridAverage"` |
%[text] | 期待單相機 SLAM 有真實尺度 | 地圖差一個未知比例 | 立體、IMU、或已知尺寸物體 |
%[text:table]
%%
%[text] # 13. 練習
%[text] 練習在 `exercise/Ch26_Exercise.m`。
%%
%[text] # 14. 延伸閱讀
%[text] - `doc disparitySGM` / `doc reconstructScene` / `doc rectifyStereoImages`
%[text] - `doc pointCloud` / `doc pcviewer`（R2026a 的大型點雲檢視器）
%[text] - `doc pcregistericp` / `doc pcregisterndt` / `doc pcregistercpd`
%[text] - `doc pcfitplane` / `doc pcsegdist` / `doc pcnormals`
%[text] - `doc monovslam` / `doc stereovslam` / `doc bundleAdjustment`
%[text] - `doc nerfacto` / `doc trainNerfacto`
%[text] - 第 27 章：用標定與三維資訊做姿態估測與 AR

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline","rightPanelPercent":40}
%---
