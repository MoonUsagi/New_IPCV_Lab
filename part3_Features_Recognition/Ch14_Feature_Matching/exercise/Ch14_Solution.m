%[text] # 第 14 章　練習解答
%[text] 特徵偵測、描述與比對
assert(exist("ch14_detect","file") == 2, ...
    "請先切換到課程根目錄並執行 ipcvSetup。");
rng(0);
I = im2gray(imread("cameraman.tif"));
R = imref2d(size(I));
%%
%[text] # 解答 1：重複性 vs 可比對性的完整地圖
%[text] 五種變換 × 七種偵測器 = 35 個點。
tfList = { rigidtform2d(15, [0 0]), ...
           rigidtform2d(45, [0 0]), ...
           simtform2d(0.7, 0, [0 0]), ...
           simtform2d(1.5, 0, [0 0]), ...
           simtform2d(0.8, 30, [0 0]) };
tfNames = ["Rot15" "Rot45" "Scale0.7" "Scale1.5" "Rot30+0.8"];
detNames = ["SIFT" "SURF" "ORB" "KAZE" "BRISK" "Harris" "FAST"];

repAll = ch14_detectorRepeatability(I);      % 欄順序與 tfList 相同

inlAll = nan(numel(detNames), numel(tfList));
for ci = 1:numel(tfList)
    warning("off", "ch14_matchAndVerify:tooFewMatches");
    T = ch14_matchAndVerify(I, tfList{ci}, Detectors=detNames);
    warning("on", "ch14_matchAndVerify:tooFewMatches");
    inlAll(:, ci) = T.Inliers;
end

fprintf("\n重複性（%%）\n%-10s", "偵測器");
fprintf("%12s", tfNames); fprintf("\n");
repVals = repAll{:, 1:numel(tfList)};
for di = 1:numel(detNames)
    fprintf("%-10s", detNames(di));
    fprintf("%12.1f", repVals(di,:));
    fprintf("\n");
end

fprintf("\n內點數\n%-10s", "偵測器");
fprintf("%12s", tfNames); fprintf("\n");
for di = 1:numel(detNames)
    fprintf("%-10s", detNames(di));
    fprintf("%12d", inlAll(di,:));
    fprintf("\n");
end
%%
%[text] ## 散佈圖與相關係數
x = repVals(:);
y = inlAll(:);
ok = isfinite(x) & isfinite(y);

rho = corr(x(ok), y(ok));
rhoS = corr(x(ok), y(ok), Type="Spearman");

fprintf("\n35 個「偵測器 x 變換」組合：\n");
fprintf("  Pearson  相關係數 = %+.4f\n", rho);
fprintf("  Spearman 相關係數 = %+.4f（排序相關，對離群值較穩健）\n", rhoS);

figure
markers = ["o" "s" "^" "d" "v" ">" "p"];
hold on
for di = 1:numel(detNames)
    plot(repVals(di,:), inlAll(di,:), markers(di), ...
        MarkerSize=10, LineWidth=1.5, DisplayName=detNames(di));
end
hold off
xlabel("重複性（%）"); ylabel("內點數")
title(sprintf("重複性無法預測配對能力（r = %+.3f）", rho))
legend(Location="northwest"); grid on
%%
%[text] ## 第 4、5 小題的答案
if rho < 0
    fprintf("\n相關係數是**負的**（%.4f）——重複性越高，內點反而越少。\n", rho);
elseif abs(rho) < 0.3
    fprintf("\n相關係數接近 0（%.4f）——兩者**幾乎沒有關係**。\n", rho);
else
    fprintf("\n相關係數是正的（%.4f）。\n", rho);
end

% 找出「重複性高但內點少」的組合
highRep = repVals > 80;
lowInl  = inlAll < 20;
badCombo = highRep & lowInl;
fprintf("\n「重複性 > 80%% 但內點 < 20」的組合有 %d 個：\n", nnz(badCombo));
[bi, bj] = find(badCombo);
for k = 1:numel(bi)
    fprintf("  %-8s %-12s 重複性 %.1f%%、內點 %d\n", ...
        detNames(bi(k)), tfNames(bj(k)), repVals(bi(k),bj(k)), inlAll(bi(k),bj(k)));
end
%[text] **第 4 小題：相關係數接近 0 甚至為負。**
%[text] 也就是說**重複性完全無法預測配對能力**——
%[text] 這是主教材第 5 節那個單一觀察的量化版本。
%[text] **第 5 小題：「重複性高但內點少」的組合幾乎全是
%[text] `BRISK`、`Harris` 與 `FAST`。** 原因分兩類：
%[text] - **`Harris` / `FAST`（`cornerPoints`）**：偵測器不提供尺度與方向，
%[text]   描述子只能用固定的取樣半徑與固定的方向。
%[text]   位置找得到，但描述子在旋轉／縮放後就對不上了。
%[text] - **`BRISK`**：有尺度與方向，但它的二元描述子維度低（64 bytes），
%[text]   區辨力不足以在大量候選中唯一決定配對，
%[text]   `matchFeatures` 的比例測試就把它們全濾掉了。
%[text] > **兩者的失效機制不同，但症狀一樣：位置對、描述子不對。**
%[text] > 這就是為什麼「偵測器好不好」這個問題本身問得不對——
%[text] > 該問的是「**偵測器 + 描述子這個組合**好不好」。
%%
%[text] # 解答 2：`validPoints` 用錯的後果
pts = detectSIFTFeatures(I);
[desc, vpts] = extractFeatures(I, pts);
fprintf("\n關鍵點 %d 個、描述子 %d 個（差 %d）\n", ...
    pts.Count, size(desc,1), size(desc,1) - pts.Count);
assert(pts.Count ~= size(desc,1), "這張影像沒有多方向指派，請換一張。");

tfTrue = simtform2d(0.8, 30, [0 0]);
J = imwarp(I, tfTrue, OutputView=R);
p2 = detectSIFTFeatures(J);
[desc2, vpts2] = extractFeatures(J, p2);

pairs = matchFeatures(desc, desc2, Unique=true);
fprintf("配對 %d 組\n", size(pairs,1));
fprintf("pairs 第一欄的最大索引 = %d（關鍵點只有 %d 個）\n", ...
    max(pairs(:,1)), pts.Count);
%%
%[text] ## 對的版本 vs 錯的版本
% --- 對的版本 ---
mRight1 = vpts(pairs(:,1));
mRight2 = vpts2(pairs(:,2));
[tfRight, inlR] = estgeotform2d(mRight2, mRight1, "similarity");

% --- 錯的版本：用 pts 而不是 vpts ---
% 索引可能越界。先看會不會直接報錯。
errMsg = "";
tfWrong = [];
try
    mWrong1 = pts(pairs(:,1));
    mWrong2 = p2(pairs(:,2));
    [tfWrong, inlW] = estgeotform2d(mWrong2, mWrong1, "similarity");
catch ME
    errMsg = string(ME.message);
end

fprintf("\n錯的版本有報錯嗎？%s\n", ...
    string(strlength(errMsg) > 0));
if strlength(errMsg) > 0
    fprintf("  訊息：%s\n", errMsg);
end
%%
%[text] ## 讓錯誤「安靜地」發生
%[text] 上面若報錯，是因為索引越界。但**只要關鍵點夠多，就不會越界**——
%[text] 錯誤會安靜地發生，這才是真正危險的情況。
%[text] 做法：只取索引在範圍內的配對，模擬「剛好沒越界」的狀況。
inRange = pairs(:,1) <= pts.Count & pairs(:,2) <= p2.Count;
fprintf("\n%d / %d 組配對的索引落在關鍵點範圍內（不會越界）\n", ...
    nnz(inRange), size(pairs,1));

sub = pairs(inRange, :);
mW1 = pts(sub(:,1));
mW2 = p2(sub(:,2));
[tfW, inlW] = estgeotform2d(mW2, mW1, "similarity", MaxNumTrials=3000);

sTrue = 1/0.8; rTrue = -30;
[sR, rR] = decompose(tfRight);
[sW, rW] = decompose(tfW);

fprintf("\n%-14s %12s %12s %12s %12s\n", ...
    "版本", "縮放", "縮放誤差", "旋轉(度)", "旋轉誤差");
fprintf("%-14s %12.4f %12.4f %12.2f %12.3f\n", ...
    "正確(vpts)", sR, abs(sR-sTrue), rR, abs(rR-rTrue));
fprintf("%-14s %12.4f %12.4f %12.2f %12.3f\n", ...
    "錯誤(pts)", sW, abs(sW-sTrue), rW, abs(rW-rTrue));
fprintf("\n正確版內點 %d / %d（%.1f%%）\n", ...
    nnz(inlR), numel(inlR), 100*mean(inlR));
fprintf("錯誤版內點 %d / %d（%.1f%%）\n", ...
    nnz(inlW), numel(inlW), 100*mean(inlW));
%[text] **第 5 小題的答案：這次它會報錯，但理由是運氣。**
%[text] 實測：配對的最大索引是 **301**，而關鍵點只有 **245** 個，
%[text] 所以直接索引越界：
%[text] ```
%[text] Index in position 1 exceeds array bounds. Index must not exceed 245.
%[text] ```
%[text] **但這是僥倖。** 越界與否取決於「配對是否剛好用到後面的索引」——
%[text] 換一張影像、換一組配對，就可能完全不越界。
%[text] 上面刻意取了**索引在範圍內的 49 組**來模擬那種情況，結果是：
%[text:table]
%[text] | 版本 | 縮放 | 旋轉 | 內點率 |
%[text] | --- | --- | --- | --- |
%[text] | **正確（`vpts`）** | 1.2500 | −29.99° | **100.0%** |
%[text] | **錯誤（`pts`）** | **0.2162** | **172.66°** | **6.1%** |
%[text:table]
%[text] 錯誤版本估出**縮放 0.22、旋轉 172.7 度**——與真實的
%[text] 縮放 1.25、旋轉 −30 度完全無關，等於隨機結果。
%[text] **好消息是內點率會塌到 6.1%**，這是一個明顯的警訊。
%[text] 所以這個 bug 的偵測方法很明確：**永遠檢查內點率**。
%[text] 內點率低於 50% 時不要相信估出來的變換，先去檢查
%[text] 是不是用錯了點陣列。
%[text] > **這就是為什麼 `extractFeatures` 要回傳第二個輸出。**
%[text] > 它不是方便功能，是**正確性的必要條件**。
%[text] > 規則很簡單：**呼叫 `extractFeatures` 之後，就再也不要碰原本的 `pts`。**
%%
%[text] # 解答 3：把 Harris 推到極限
fprintf("\n=== 逐步改善 Harris 的配對能力 ===\n");
fprintf("%-40s %10s %10s %10s\n", "設定", "點數", "配對數", "內點數");

results = struct("name", {}, "pts", {}, "matches", {}, "inliers", {});

% 基準：主教材的設定
[n0, m0, i0] = harrisTrial(I, J, "MinQuality", 0.01, "Method", "SURF", ...
    "MaxRatio", 0.6, "Select", "none");
results(end+1) = struct("name","基準（MinQuality 0.01 + SURF）", ...
    "pts",n0,"matches",m0,"inliers",i0);

% 手段 1：降低 MinQuality 取更多點
for mq = [0.005 0.001 0.0001]
    [n1, m1, i1] = harrisTrial(I, J, "MinQuality", mq, "Method", "SURF", ...
        "MaxRatio", 0.6, "Select", "none");
    results(end+1) = struct("name", sprintf("MinQuality %.4f + SURF", mq), ...
        "pts",n1,"matches",m1,"inliers",i1);
end

% 手段 2：放寬 MaxRatio
for mr = [0.8 1.0]
    [n2, m2, i2] = harrisTrial(I, J, "MinQuality", 0.0001, "Method", "SURF", ...
        "MaxRatio", mr, "Select", "none");
    results(end+1) = struct("name", sprintf("MinQuality 0.0001 + SURF + MaxRatio %.1f", mr), ...
        "pts",n2,"matches",m2,"inliers",i2);
end

% 手段 3：selectUniform 讓點分布均勻
[n3, m3, i3] = harrisTrial(I, J, "MinQuality", 0.0001, "Method", "SURF", ...
    "MaxRatio", 0.8, "Select", "uniform");
results(end+1) = struct("name","+ selectUniform(600)", ...
    "pts",n3,"matches",m3,"inliers",i3);

% 手段 4：換 KAZE 描述子
[n4, m4, i4] = harrisTrial(I, J, "MinQuality", 0.0001, "Method", "KAZE", ...
    "MaxRatio", 0.8, "Select", "none");
results(end+1) = struct("name","MinQuality 0.0001 + KAZE + MaxRatio 0.8", ...
    "pts",n4,"matches",m4,"inliers",i4);

for k = 1:numel(results)
    fprintf("%-40s %10d %10d %10d\n", results(k).name, ...
        results(k).pts, results(k).matches, results(k).inliers);
end

% SIFT 基準線
pS1 = detectSIFTFeatures(I); pS2 = detectSIFTFeatures(J);
[fS1, vS1] = extractFeatures(I, pS1);
[fS2, vS2] = extractFeatures(J, pS2);
prS = matchFeatures(fS1, fS2, Unique=true);
[~, inS] = estgeotform2d(vS2(prS(:,2)), vS1(prS(:,1)), "similarity");
fprintf("\n%-40s %10d %10d %10d  <- 對照\n", "SIFT（預設）", ...
    pS1.Count, size(prS,1), nnz(inS));

bestInl = max([results.inliers]);
fprintf("\nHarris 的最佳內點數 = %d，SIFT = %d\n", bestInl, nnz(inS));
%[text] **第 4 小題：能追上 SIFT 嗎？**
%[text] 把點數從 184 加到上千之後，配對數確實會上升——
%[text] 但**內點率會同時下降**，因為多出來的點大多是弱角點，
%[text] 描述子更不穩定。
%[text] **缺的東西是結構性的，不是參數：`cornerPoints` 沒有尺度與方向。**
%[text] - 沒有**尺度** → 描述子只能用固定的取樣半徑。
%[text]   影像縮放 0.8 之後，同一個物理鄰域在兩張圖裡對應到
%[text]   **不同大小**的像素區域，描述子自然對不上。
%[text] - 沒有**方向** → 描述子無法對齊到主方向。
%[text]   旋轉 30° 之後，`SURF` 描述子的取樣格點跟著影像轉了，
%[text]   但它不知道要轉回來。
%[text] SIFT 在偵測階段就決定了每個點的尺度與主方向，
%[text] 描述子據此**正規化**，所以旋轉縮放後仍然一致。
%[text] > **這不是調參數能補的差距。**
%[text] > 要在 Harris 點上得到不變性，唯一的辦法是**自己估尺度與方向**
%[text] > 再餵給描述子——而那基本上就是在重寫 SIFT 了。
%[text] > 真正的結論是：**選對偵測器比調參數重要得多。**
%%
%[text] # 解答 4：三張拼接與誤差累積
%[text] 先做一件比串接更基本的事：**確認為什麼非得串接不可。**
Big = im2gray(imread("peppers.png"));

% 第一組切法：左右兩段完全沒有重疊
farL = Big(:,   1:220);
farM = Big(:, 150:370);
farR = Big(:, 300:512);
fprintf("\n切法 A：左 1-220、中 150-370、右 300-512\n");
fprintf("  左-中 重疊 %d 欄、中-右 重疊 %d 欄、**左-右 重疊 0 欄**\n", ...
    220-150+1, 370-300+1);

fprintf("\n%-14s %10s\n", "配對", "配對數");
fprintf("%-14s %10d\n", "中 -> 左", countMatches(farM, farL));
fprintf("%-14s %10d\n", "右 -> 中", countMatches(farR, farM));
fprintf("%-14s %10d  <- 完全配不到\n", "右 -> 左", countMatches(farR, farL));
%[text] **左圖與右圖沒有任何共同內容，所以直接估「右→左」得到 0 組配對。**
%[text] 這正是**必須串接**的理由：真實的全景照片裡，
%[text] 第 1 張與第 20 張根本拍的不是同一片場景。
%[text] > **串接不是一種偷懶的做法，是唯一可行的做法。**
%[text] > 而串接的代價就是誤差會沿著鏈條傳遞。
%%
%[text] ## 用有重疊的切法，才能把串接與直接估做比較
%[text] 為了量化串接誤差，改用一組**左右仍有重疊**的切法，
%[text] 這樣「直接估」才存在，可以當作參考答案。
segL = Big(:,   1:300);
segM = Big(:, 160:460);
segR = Big(:, 260:512);
fprintf("\n切法 B：左 1-300、中 160-460、右 260-512\n");
fprintf("  左-中 重疊 %d 欄、中-右 重疊 %d 欄、左-右 重疊 %d 欄\n", ...
    300-160+1, 460-260+1, 300-260+1);
fprintf("  真實位移：中->左 159、右->中 100、右->左 259\n");

tfML = estimatePair(segM, segL);     % 中 -> 左
tfRM = estimatePair(segR, segM);     % 右 -> 中
tfRL = estimatePair(segR, segL);     % 右 -> 左（直接估，當參考答案）

% 串接：先把右對到中，再把中對到左。
% tform 的 A 用「左乘行向量」慣例，所以複合變換是 A_ML * A_RM
tfChain = projtform2d(tfML.A * tfRM.A);

fprintf("\n%-24s %14s %14s\n", "方式", "估計 x 位移", "與真實 259 的差");
fprintf("%-24s %14.3f %14.3f\n", "直接估 右->左", ...
    tfRL.A(1,3), abs(tfRL.A(1,3) - 259));
fprintf("%-24s %14.3f %14.3f\n", "串接 (中->左)(右->中)", ...
    tfChain.A(1,3), abs(tfChain.A(1,3) - 259));

fprintf("\n個別段的誤差：\n");
e1 = abs(tfML.A(1,3) - 159);
e2 = abs(tfRM.A(1,3) - 100);
fprintf("  中->左：%.3f（真實 159），誤差 %.4f\n", tfML.A(1,3), e1);
fprintf("  右->中：%.3f（真實 100），誤差 %.4f\n", tfRM.A(1,3), e2);
fprintf("  兩段誤差和 = %.4f\n", e1 + e2);
fprintf("  串接後的誤差 = %.4f\n", abs(tfChain.A(1,3) - 259));
%%
%[text] ## 第 6 小題：誤差會累積嗎
eChain  = abs(tfChain.A(1,3) - 259);
eDirect = abs(tfRL.A(1,3) - 259);

fprintf("\n串接誤差 %.4f、直接估誤差 %.4f\n", eChain, eDirect);
fprintf("兩者相差 %.4f 像素\n", abs(tfChain.A(1,3) - tfRL.A(1,3)));
if eChain > max(e1, e2)
    fprintf("串接誤差**大於**任一單段誤差 -> 誤差在累積\n");
else
    fprintf("串接誤差未超過單段誤差 -> 這次部分抵消了\n");
end

perStep = mean([e1 e2]);
fprintf("\n若每段平均誤差 %.4f 像素：\n", perStep);
fprintf("  最壞情況（誤差同向，線性累積）20 段 -> %.3f 像素\n", 20*perStep);
fprintf("  隨機漫步（誤差獨立）20 段         -> %.3f 像素\n", sqrt(20)*perStep);

figure
nSeg = 1:20;
plot(nSeg, nSeg*perStep, "o-", LineWidth=1.8, DisplayName="最壞情況（線性 n）")
hold on
plot(nSeg, sqrt(nSeg)*perStep, "s-", LineWidth=1.8, DisplayName="隨機漫步（\surd n）")
yline(2, "--", "2 像素（肉眼可見的接縫）", LineWidth=1.2);
hold off
xlabel("串接的影像段數"); ylabel("預期累積誤差（像素）")
title("拼接誤差如何隨影像數成長"); legend(Location="northwest"); grid on
%[text] **誤差會累積，成長方式取決於誤差有沒有系統性偏差：**
%[text] - **獨立隨機誤差** → 以 $\sqrt{n}$ 成長（隨機漫步）
%[text] - **有系統性偏差**（例如鏡頭畸變沒校正）→ 以 $n$ **線性**成長
%[text] 單段誤差在本例只有零點幾個像素，看起來微不足道。
%[text] 但全景照片的接縫錯開 **2–3 像素就看得出來**，
%[text] 而線性累積下二十段就會到那個量級。
%[text] > **這就是為什麼實務的 panorama 不是「一段一段串下去」。**
%[text] > 正確做法是 **bundle adjustment**：把所有影像的變換參數放在一起，
%[text] > 最小化**全部**配對點的重投影誤差，讓誤差平均分攤而不是往末端堆。
%[text] MATLAB 的 `imageviewset` + `bundleAdjustment`（Computer Vision Toolbox）
%[text] 就是做這件事的，第 27 章會用到。
%[text] 另外注意本例的兩段串接**誤差反而變小**（部分抵消）——
%[text] 這是**單一樣本的巧合**，不能據此推論「誤差會抵消」。
%[text] 要判斷累積行為，必須跑多組不同的切法看統計，
%[text] 而不是看一次的結果。
%%
%[text] # 解答 5：把檢索題目變難
% 資料庫大小要節制：bagOfFeatures 的分群成本隨影像數成長很快，
% 而詞彙表掃描還要重建好幾次索引。
srcList = ["peppers.png" "cameraman.tif" "circuit.tif" ...
           "fabric.png" "coins.png" "onion.png"];
variantNames = ["原圖" "旋轉40度" "裁切60%" "雜訊0.02"];

tmp = fullfile(tempdir, "ipcv_ch14_hard");
if isfolder(tmp), rmdir(tmp, "s"); end
mkdir(tmp);

labels = strings(0); variants = strings(0); n = 0;
rng(0);
for s = srcList
    try
        A = imread(s);
    catch
        continue
    end
    if size(A,3) == 1, A = repmat(A,1,1,3); end
    A = imresize(A, [256 256]);
    for v = 1:numel(variantNames)
        B = makeVariant(A, v);
        n = n + 1;
        imwrite(B, fullfile(tmp, sprintf("h_%03d.png", n)));
        labels(n) = s; variants(n) = variantNames(v);
    end
end
fprintf("\n困難資料庫：%d 張（%d 來源 x %d 變體）\n", ...
    n, numel(unique(labels)), numel(variantNames));

warning("off","all");
evalc("hardIdx = indexImages(imageDatastore(tmp));");
warning("on","all");

% 逐一查詢，排除自身
K = 4;
hitByVariant = zeros(1, numel(variantNames));
cntByVariant = zeros(1, numel(variantNames));
for qi = 1:n
    Q = imread(fullfile(tmp, sprintf("h_%03d.png", qi)));
    [ids, ~] = retrieveImages(Q, hardIdx, NumResults=K+1);
    ids = ids(:)';
    ids = ids(ids ~= qi);
    top = ids(1:min(K, numel(ids)));
    vi = find(variantNames == variants(qi));
    hitByVariant(vi) = hitByVariant(vi) + nnz(labels(top) == labels(qi));
    cntByVariant(vi) = cntByVariant(vi) + numel(top);
end

fprintf("\n%-14s %10s %10s %12s\n", "變體", "命中", "總數", "精確度");
for v = 1:numel(variantNames)
    fprintf("%-14s %10d %10d %11.1f%%" + "\n", variantNames(v), ...
        hitByVariant(v), cntByVariant(v), 100*hitByVariant(v)/cntByVariant(v));
end
overall = 100*sum(hitByVariant)/sum(cntByVariant);
fprintf("%-14s %10d %10d %11.1f%%" + "\n", "整體", ...
    sum(hitByVariant), sum(cntByVariant), overall);

[~, worstV] = min(hitByVariant ./ cntByVariant);
fprintf("\n最難檢索的變體是「%s」（%.1f%%）\n", variantNames(worstV), ...
    100*hitByVariant(worstV)/cntByVariant(worstV));
[~, bestVar] = max(hitByVariant ./ cntByVariant);
fprintf("最容易的是「%s」（%.1f%%）\n", variantNames(bestVar), ...
    100*hitByVariant(bestVar)/cntByVariant(bestVar));
%%
%[text] ## 第 3 小題：哪一種變體最容易失敗
%[text] 實測（6 來源 × 4 變體 = 24 張，取前 4 名且排除自身）：
%[text:table]
%[text] | 變體 | 精確度 |
%[text] | --- | --- |
%[text] | 原圖 | 66.7% |
%[text] | 旋轉 40° | 62.5% |
%[text] | 裁切 60% | 62.5% |
%[text] | **雜訊 0.02** | **29.2%** |
%[text] | **整體** | **55.2%** |
%[text:table]
%[text] **雜訊是最致命的，精確度只有其他變體的一半。**
%[text] 而旋轉 40° 與裁切 60% 幾乎沒有傷害（62.5% vs 原圖的 66.7%）。
%[text] 原因直接對應本章第 3–5 節：
%[text] - **旋轉**：SURF 有方向估計，描述子會正規化，所以幾乎免疫
%[text] - **裁切**：只是少了一部分特徵，剩下的仍然正確
%[text] - **雜訊**：會**改變描述子本身的數值**，而且是在每一個特徵上。
%[text]   視覺詞的指派因此全部偏移——這不是「少了一些特徵」，
%[text]   而是「所有特徵都變成別的詞」
%[text] > **對 Bag-of-Features 來說，雜訊比幾何變換危險得多。**
%[text] > 這與直覺相反——旋轉 40 度看起來變化「很大」，
%[text] > 但描述子是設計來抵抗它的；雜訊看起來變化「很小」，
%[text] > 卻直接攻擊描述子的數值。
%[text] 實務上這代表：**檢索系統的前處理應該優先去雜訊，
%[text] 而不是花力氣做幾何正規化。**
%%
%[text] ## 第 4、5 小題：詞彙表大小的影響
vocabSizes = [80 400];   % 只掃兩個尺寸：bagOfFeatures 的分群很耗時
precByVocab = zeros(size(vocabSizes));

for k = 1:numel(vocabSizes)
    warning("off","all");
    cmd = sprintf(['bag = bagOfFeatures(imageDatastore(tmp), ' ...
                   'VocabularySize=%d, Verbose=false); ' ...
                   'vIdx = indexImages(imageDatastore(tmp), bag);'], vocabSizes(k));
    evalc(cmd);
    warning("on","all");

    hits = 0; tot = 0;
    for qi = 1:n
        Q = imread(fullfile(tmp, sprintf("h_%03d.png", qi)));
        [ids, ~] = retrieveImages(Q, vIdx, NumResults=K+1);
        ids = ids(:)'; ids = ids(ids ~= qi);
        top = ids(1:min(K, numel(ids)));
        hits = hits + nnz(labels(top) == labels(qi));
        tot = tot + numel(top);
    end
    precByVocab(k) = 100*hits/tot;
    fprintf("VocabularySize %4d -> 精確度 %.1f%%" + "\n", vocabSizes(k), precByVocab(k));
end

figure
plot(vocabSizes, precByVocab, "o-", LineWidth=1.8)
xlabel("VocabularySize"); ylabel("精確度（%，排除自身）")
title("視覺詞彙表大小 vs 檢索精確度"); grid on
[~, bestV] = max(precByVocab);
fprintf("\n本例最佳詞彙表大小 = %d（精確度 %.1f%%）\n", ...
    vocabSizes(bestV), precByVocab(bestV));
fprintf("對照：indexImages 的**預設**詞彙表得到 %.1f%%" + "\n", overall);
if bestV == numel(vocabSizes)
    fprintf("\n**注意：最佳值落在掃描範圍的邊界**，\n");
    fprintf("代表還沒掃到「詞彙表過大反而變差」的區間。\n");
end
%[text] **理論上詞彙表大小是一個「兩邊都會壞」的參數：**
%[text] - **太小** → 不同的東西被歸到同一個視覺詞，區辨力不足
%[text] - **太大** → 同一個東西的兩個實例被分到不同的詞，比對不上
%[text] 所以應該有一個中間的最佳值。**但實測沒有看到那個轉折點：**
%[text:table]
%[text] | VocabularySize | 精確度（排除自身） |
%[text] | --- | --- |
%[text] | 80 | 19.8% |
%[text] | **400** | **46.9%** |
%[text] | *（`indexImages` 預設）* | ***55.2%*** |
%[text:table]
%[text] 精確度**單調上升到掃描範圍的邊界**，而且兩個手動設定
%[text] **都輸給預設值**——80 的表現只有預設值的三分之一。
%[text] 誠實的結論是：**這次的實驗沒有找到最佳值，只證明了「還不夠大」。**
%[text] 原因是資料庫只有 24 張影像，總特徵數有限——
%[text] 詞彙表還沒大到會把同一個東西拆散的程度。
%[text] 要看到轉折點，需要把詞彙表推到接近總特徵數，
%[text] 或者用更大的資料庫讓兩個效應都有空間展現。
%[text] > **掃描範圍的邊界值不是最佳值，是「你還沒掃夠」的訊號。**
%[text] > 這與第 12 章練習 5 的膨脹量掃描是同一個提醒。
%[text] 實務上：**先用預設值**，它是依資料自動決定的；
%[text] 真要調的話，記得詞彙表大小必須跟著資料量一起成長。
%[text] 真實任務的詞彙表通常是數千到數萬，而那需要數千張訓練影像。
%%
%[text] # 加分題：特徵法 vs 強度法
shifts = [5 10 20 40 60 80 100];
errInt = nan(size(shifts));
errFeat = nan(size(shifts));

fprintf("\n%-10s %16s %16s\n", "真實位移", "強度法誤差", "特徵法誤差");
[optimizer, metric] = imregconfig("monomodal");

for k = 1:numel(shifts)
    sx = shifts(k);
    tfShift = transltform2d(sx, 0);
    Jm = imwarp(I, tfShift, OutputView=R);

    % --- 強度法 ---
    try
        tfI = imregtform(Jm, I, "translation", optimizer, metric);
        errInt(k) = abs(abs(tfI.A(1,3)) - sx);
    catch
        errInt(k) = NaN;
    end

    % --- 特徵法 ---
    try
        a1 = detectSIFTFeatures(I); a2 = detectSIFTFeatures(Jm);
        [b1, u1] = extractFeatures(I, a1);
        [b2, u2] = extractFeatures(Jm, a2);
        pr = matchFeatures(b1, b2, Unique=true);
        if size(pr,1) >= 4
            tfF = estgeotform2d(u2(pr(:,2)), u1(pr(:,1)), "similarity");
            errFeat(k) = abs(abs(tfF.A(1,3)) - sx);
        end
    catch
        errFeat(k) = NaN;
    end

    fprintf("%-10d %16.4f %16.4f\n", sx, errInt(k), errFeat(k));
end

figure
semilogy(shifts, max(errInt, 1e-4), "o-", LineWidth=1.8, DisplayName="強度法 imregtform")
hold on
semilogy(shifts, max(errFeat, 1e-4), "s-", LineWidth=1.8, DisplayName="特徵法 SIFT")
yline(1, "--", "1 像素", LineWidth=1.2);
hold off
xlabel("真實位移（像素）"); ylabel("估計誤差（像素，對數軸）")
title("大位移時強度法會失敗，特徵法不會"); legend(Location="northwest"); grid on

failIdx = find(errInt > 1, 1, "first");
if ~isempty(failIdx)
    fprintf("\n強度法在位移 %d 像素開始誤差超過 1 像素\n", shifts(failIdx));
else
    fprintf("\n強度法在測試範圍內都沒有失敗\n");
end
%%
%[text] ## 第 6 小題：設計一個**特徵法會輸**的情況
%[text] 特徵法需要**可重複偵測的關鍵點**。
%[text] 什麼影像沒有？——**沒有紋理的影像**。
%[text] 這與第 12 章的觀察相通：那些讓無參考指標失效的影像
%[text] （統計特性遠離自然照片的），也常常是特徵法失效的影像。
%[text] 造一張幾乎沒有角點的平滑漸層影像，**然後驗證特徵法真的失敗**。
[gx, gy] = meshgrid(linspace(0,1,256), linspace(0,1,256));
smoothImg = im2uint8(0.3 + 0.4*gx + 0.2*gy);      % 純線性漸層，無角點
smoothImg = imgaussfilt(smoothImg, 2);
Rs = imref2d(size(smoothImg));

nPts = detectSIFTFeatures(smoothImg).Count;
fprintf("\n平滑漸層影像的 SIFT 關鍵點數 = %d\n", nPts);

sxTest = 20;
Js = imwarp(smoothImg, transltform2d(sxTest, 0), OutputView=Rs);

% 特徵法
featOK = false; featErr = NaN;
try
    c1 = detectSIFTFeatures(smoothImg); c2 = detectSIFTFeatures(Js);
    if c1.Count >= 4 && c2.Count >= 4
        [d1s, e1s] = extractFeatures(smoothImg, c1);
        [d2s, e2s] = extractFeatures(Js, c2);
        prs = matchFeatures(d1s, d2s, Unique=true);
        if size(prs,1) >= 4
            tfs = estgeotform2d(e2s(prs(:,2)), e1s(prs(:,1)), "similarity");
            featErr = abs(abs(tfs.A(1,3)) - sxTest);
            featOK = true;
        end
    end
catch
end

% 強度法
[optimizer2, metric2] = imregconfig("monomodal");
tfIs = imregtform(Js, smoothImg, "translation", optimizer2, metric2);
intErr = abs(abs(tfIs.A(1,3)) - sxTest);

fprintf("位移 %d 像素：\n", sxTest);
if featOK
    fprintf("  特徵法誤差 = %.4f 像素\n", featErr);
else
    fprintf("  **特徵法失敗**：關鍵點或配對不足，估不出變換\n");
end
fprintf("  強度法誤差 = %.4f 像素\n", intErr);

figure
tiledlayout(1,2, TileSpacing="compact")
nexttile; imshow(smoothImg); title(sprintf("平滑漸層（SIFT 只找到 %d 點）", nPts))
nexttile; imshow(I); title(sprintf("cameraman（SIFT 找到 %d 點）", ...
    detectSIFTFeatures(I).Count))
%[text] **驗證成功**：平滑漸層影像上 SIFT 幾乎找不到關鍵點，
%[text] 特徵法估不出變換；強度法卻能正常運作，
%[text] 因為它比對的是**整張影像的強度分布**，不需要角點。
%[text] **兩種方法的適用範圍是互補的：**
%[text:table]
%[text] | 情況 | 強度法 | 特徵法 |
%[text] | --- | --- | --- |
%[text] | 大位移／大旋轉 | ✗ 容易掉進局部極值 | ✓ |
%[text] | 平滑、無紋理 | ✓ | ✗ 沒有關鍵點 |
%[text] | 局部遮擋 | ✗ 被遮擋區拉偏 | ✓ 外點會被 MSAC 剔除 |
%[text] | 多模態（不同感測器） | ✓ 用互資訊 | ✗ 描述子對不上 |
%[text] | 需要次像素精度 | ✓ | ✓（內點夠多時） |
%[text:table]
%[text] > **這題的方法論重點在「驗證你的困難案例真的困難」。**
%[text] > 第 10 章練習 4 與第 12 章都踩過這個坑：
%[text] > 設計了一個以為很難的測試，結果方法輕鬆通過，
%[text] > 於是得到錯誤的結論。
%[text] > 這裡先**印出關鍵點數**確認影像真的沒有特徵，才下結論。

% ========================================================================
function [s, rotDeg] = decompose(tf)
%DECOMPOSE 從相似變換矩陣取出縮放與旋轉角。
A = tf.A;
s = hypot(A(1,1), A(1,2));
rotDeg = atan2d(A(2,1), A(1,1));
end

% ========================================================================
function [nPts, nMatch, nInl] = harrisTrial(I, J, varargin)
%HARRISTRIAL 用指定的設定跑一次 Harris 配對，回傳點數/配對數/內點數。
q = inputParser;
addParameter(q, "MinQuality", 0.01);
addParameter(q, "Method", "SURF");
addParameter(q, "MaxRatio", 0.6);
addParameter(q, "Select", "none");
parse(q, varargin{:});
o = q.Results;

p1 = detectHarrisFeatures(I, MinQuality=o.MinQuality);
p2 = detectHarrisFeatures(J, MinQuality=o.MinQuality);

if o.Select == "uniform"
    p1 = selectUniform(p1, min(600, p1.Count), size(I));
    p2 = selectUniform(p2, min(600, p2.Count), size(J));
end

nPts = p1.Count;
[f1, v1] = extractFeatures(I, p1, Method=o.Method);
[f2, v2] = extractFeatures(J, p2, Method=o.Method);
pairs = matchFeatures(f1, f2, Unique=true, MaxRatio=o.MaxRatio);
nMatch = size(pairs,1);

if nMatch < 4
    nInl = 0;
    return
end
[~, inl] = estgeotform2d(v2(pairs(:,2)), v1(pairs(:,1)), ...
    "similarity", MaxNumTrials=3000);
nInl = nnz(inl);
end

% ========================================================================
function n = countMatches(moving, fixed)
%COUNTMATCHES 只回傳配對數，用來檢查兩張影像有沒有共同內容。
pm = detectSIFTFeatures(moving);
pf = detectSIFTFeatures(fixed);
[fm, ~] = extractFeatures(moving, pm);
[ff, ~] = extractFeatures(fixed, pf);
n = size(matchFeatures(fm, ff, Unique=true), 1);
end

% ========================================================================
function tf = estimatePair(moving, fixed)
%ESTIMATEPAIR 估 moving -> fixed 的投影變換。
pm = detectSIFTFeatures(moving);
pf = detectSIFTFeatures(fixed);
[fm, vm] = extractFeatures(moving, pm);
[ff, vf] = extractFeatures(fixed, pf);
pairs = matchFeatures(fm, ff, Unique=true);
if size(pairs,1) < 4
    error("estimatePair:tooFewMatches", ...
        "只有 %d 組配對，重疊可能不足。", size(pairs,1));
end
tf = estgeotform2d(vm(pairs(:,1)), vf(pairs(:,2)), "projective", ...
    MaxNumTrials=3000);
end

% ========================================================================
function B = makeVariant(A, v)
%MAKEVARIANT 產生第 v 種變體，用於加大檢索難度。
switch v
    case 1, B = A;
    case 2, B = imrotate(A, 40, "bilinear", "crop");
    case 3
        h = size(A,1); w = size(A,2);
        r0 = round(0.2*h); c0 = round(0.2*w);
        B = imresize(A(r0:r0+round(0.6*h)-1, c0:c0+round(0.6*w)-1, :), [h w]);
    case 4, B = imnoise(A, "gaussian", 0, 0.02);
    case 5, B = im2uint8(min(im2double(A)*1.6, 1));
end
end

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline","rightPanelPercent":40}
%---
