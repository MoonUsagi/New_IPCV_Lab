%[text] # 第 26 章　練習解答
%[text] {"align":"left"}3D 視覺、點雲與場景重建　｜　MATLAB R2026b
%[text] > **練習 5 撞到一個硬限制**：`disparitySGM` 的視差範圍長度
%[text] > **不能超過 128**，所以有些工作距離**在物理上就涵蓋不了**。
%[text] > 練習 1 也推翻了一個直覺：紋理只能解釋 64% 的失敗。
assert(exist("ch26_stereoDepth", "file") == 2, ...
    "請先切換到課程根目錄並執行 ipcvSetup。");
rng(0);

dataDir = fullfile(toolboxdir("vision"), "visiondata");
stereoData = load(fullfile(dataDir, "handshakeStereoParams.mat"));
stereoParams = stereoData.stereoParams;
[baseCloud, baseReport] = ch26_stereoDepth();
%%
%[text] # 解答 1　沒有深度的像素長在哪裡
disparityMap = baseReport.DisparityMap;
rectLeft     = baseReport.RectifiedLeft;
texture      = stdfilt(rgb2gray(rectLeft), ones(9));
hasDisparity = isfinite(disparityMap);

texValid   = texture(hasDisparity);
texInvalid = texture(~hasDisparity);
fprintf("有視差的像素：紋理中位數 %.2f（四分位 %.2f – %.2f）\n", ...
    median(texValid), prctile(texValid,25), prctile(texValid,75));
fprintf("沒視差的像素：紋理中位數 %.2f（四分位 %.2f – %.2f）\n", ...
    median(texInvalid), prctile(texInvalid,25), prctile(texInvalid,75));

thresholds = 1:0.5:15;
accuracy = zeros(size(thresholds));
for i = 1:numel(thresholds)
    predicted = texture > thresholds(i);
    accuracy(i) = nnz(predicted == hasDisparity) / numel(hasDisparity);
end
[bestAcc, bestIdx] = max(accuracy);
fprintf("\n用紋理門檻預測「會不會有視差」：\n");
fprintf("  最佳門檻 %.1f，準確率 **%.1f%%**\n", thresholds(bestIdx), bestAcc*100);

figure;
tiledlayout(2,2, TileSpacing="compact");
nexttile; imshow(rectLeft); title("校正後左影像")
nexttile; imshow(~hasDisparity); title("沒有視差的像素（白）")
nexttile; imshow(texture, []); title("局部紋理強度")
nexttile
histogram(texValid, 0:0.5:30, Normalization="probability"); hold on
histogram(texInvalid, 0:0.5:30, Normalization="probability");
legend("有視差", "沒視差"); xlabel("紋理強度"); grid on
title("兩組的紋理分布重疊很多")
%[text] ## 量到的結果
%[text:table]
%[text] | | 紋理中位數 | 四分位距 |
%[text] | --- | --- | --- |
%[text] | **有視差** | **4.92** | 2.06 – 11.30 |
%[text] | **沒視差** | **2.09** | 1.52 – 5.91 |
%[text:table]
%[text] **紋理確實是一個訊號**（中位數差 2.4 倍），
%[text] **但它只能解釋一部分**：最佳門檻的預測準確率只有 **64.4%**。
%[text] > **而隨便猜「全部都有視差」就有 52.7% 的準確率。**
%[text] > 所以紋理這個特徵只帶來 **11.7 個百分點**的提升——
%[text] > 遠不足以解釋失敗。
%[text] **第 5 小題：剩下的失敗在哪裡？** 看第二張圖，
%[text] 白色（沒視差）的區域**明顯集中在物體邊緣與人的輪廓周圍**。
%[text] 那是**遮擋**——左相機看得到、右相機看不到的區域。
%[text:table]
%[text] | 原因 | 能用紋理預測嗎 | 能改善嗎 |
%[text] | --- | --- | --- |
%[text] | 紋理不足 | ✅ 可以 | 打投影紋理 |
%[text] | **遮擋** | ❌ **不行**（邊緣的紋理通常很強） | **不能，幾何必然** |
%[text] | 超出視差範圍 | ❌ 不行 | 調範圍（練習 5） |
%[text:table]
%[text] > **遮擋區的紋理往往是整張影像最強的**（物體邊緣），
%[text] > 所以它是紋理預測器的主要錯誤來源——
%[text] > **一個「高紋理卻沒有視差」的像素，幾乎一定是遮擋。**
%[text] **第 6 小題**：本機量到校正後**沒有純黑邊**
%[text]（非黑像素 100.0%），所以這裡不需要特別處理。
%[text] 但換一組標定參數時校正可能產生黑邊，
%[text] **那些像素該從統計裡排除**——否則「有效率」會被稀釋，
%[text] 而那和演算法完全無關。
%%
%[text] # 解答 2　把 NaN 當成 0 會發生什麼事
vLeft  = VideoReader(fullfile(dataDir, "handshake_left.avi"));
vRight = VideoReader(fullfile(dataDir, "handshake_right.avi"));
[rectL, rectR, reprojMatrix] = rectifyStereoImages( ...
    read(vLeft,50), read(vRight,50), stereoParams);
dMap = disparitySGM(rgb2gray(rectL), rgb2gray(rectR), DisparityRange=[0 64]);

pointsKeepNaN = reconstructScene(dMap, reprojMatrix) / 1000;
dZero = dMap;
dZero(~isfinite(dZero)) = 0;
pointsZero = reconstructScene(dZero, reprojMatrix) / 1000;

cloudKeepNaN = pointCloud(pointsKeepNaN);
cloudZero    = pointCloud(pointsZero);

fprintf("保留 NaN：Count = %d，Z 範圍 %.1f .. %.1f\n", ...
    cloudKeepNaN.Count, cloudKeepNaN.ZLimits(1), cloudKeepNaN.ZLimits(2));
fprintf("NaN → 0 ：Count = %d，Z 範圍 %.1f .. %.1f\n", ...
    cloudZero.Count, cloudZero.ZLimits(1), cloudZero.ZLimits(2));

zZero = pointsZero(:,:,3);
fprintf("NaN → 0 的版本有 %d 點（**%.1f%%**）的 |Z| > 1000 公尺\n", ...
    nnz(abs(zZero) > 1000), nnz(abs(zZero) > 1000)/numel(zZero)*100);

warnState = warning("off", "vision:ransac:maxTrialsReached");
planeKeepNaN = pcfitplane(cloudKeepNaN, 0.05);
planeZero    = pcfitplane(cloudZero, 0.05);
warning(warnState);
fprintf("\n擬合平面的法向量：\n");
fprintf("  保留 NaN：%s\n", mat2str(round(planeKeepNaN.Normal, 3)));
fprintf("  NaN → 0 ：%s\n", mat2str(round(planeZero.Normal, 3)));
fprintf("  **兩者夾角 %.1f 度**\n", ...
    acosd(min(1, abs(dot(planeKeepNaN.Normal, planeZero.Normal)))));
%[text] ## 量到的結果
%[text:table]
%[text] | | 保留 `NaN` | **`NaN` → 0** |
%[text] | --- | --- | --- |
%[text] | `Count` | 369566 | **369566（一模一樣）** |
%[text] | Z 範圍 | 1.0 .. Inf | 1.0 .. Inf |
%[text] | \|Z\| > 1000 m 的點 | — | **174973（47.3%）** |
%[text] | 擬合平面法向量 | `[-0.017 -0.062 -0.998]` | `[0.107 0.072 0.992]` |
%[text:table]
%[text] **第 2 小題：`Count` 完全一樣。**
%[text] `pointCloud` **不會把 `NaN` 點丟掉**——它們照樣佔一個位置。
%[text] 所以「點雲有多少點」這個數字**完全無法告訴你資料的品質**。
%[text] **第 5、6 小題：平面差了 5.2 度，而且過程中只有一個警告。**
%[text] （R2026a 是 6.3 度。R2026b 的 `pcfitplane` 會用內點再精修一次，但**被汙染的點雲照樣歪掉**。）
%[text] `pcfitplane` 對被汙染的點雲發了
%[text] 「Maximum number of trials reached」——
%[text] 那是 MSAC 在說「我找不到一個好的共識集」，
%[text] **但它還是回傳了一個平面**。
%[text] > ## **這個錯誤要到很後面才會被發現**
%[text:table]
%[text] | 步驟 | 會抱怨嗎 |
%[text] | --- | --- |
%[text] | `reconstructScene` | ❌ 不會 |
%[text] | `pointCloud` 建構 | ❌ 不會 |
%[text] | `pcshow` | ❌ 不會（自動忽略遠點的顯示） |
%[text] | `pcfitplane` | ⚠ **只發一個警告，照樣回傳** |
%[text] | **你的量測結果** | ✅ **偏 5.2 度** |
%[text:table]
%[text] **注意「保留 NaN」的版本 Z 上限也是 Inf**——
%[text] 那是視差**接近**零（不是 NaN）的像素造成的，是 §4 的問題。
%[text] **兩個問題要分開處理**：`NaN` 要保留，**過小的視差要另外過濾**。
%[text] 這正是 `ch26_stereoDepth` 用 `MinDepth`／`MaxDepth` 做的事。
%%
%[text] # 解答 3　離群點不是隨機分布的
%[text] ## 我的預期
%[text] 「MSAC 撐到 50% 應該沒問題，畢竟它是為了抗離群點設計的。」
trueNormal = [0.3 -0.2 -1] / norm([0.3 -0.2 -1]);
secondNormal = localRotateNormal(trueNormal, 30);

fractions = [0.10 0.30 0.45 0.55]';
FoundMain   = zeros(numel(fractions),1);
ErrToMain   = zeros(numel(fractions),1);
ErrToSecond = zeros(numel(fractions),1);
nRepeat = 10;
if ipcvFast(), nRepeat = 4; end

for i = 1:numel(fractions)
    cloud = localTwoPlanes(3000, fractions(i), trueNormal, secondNormal);
    hitMain = 0;
    e1 = zeros(nRepeat,1);
    e2 = zeros(nRepeat,1);
    for r = 1:nRepeat
        model = pcfitplane(cloud, 0.05);
        e1(r) = localAngle(model.Normal, trueNormal);
        e2(r) = localAngle(model.Normal, secondNormal);
        hitMain = hitMain + (e1(r) < e2(r));
    end
    FoundMain(i)   = hitMain / nRepeat * 100;
    ErrToMain(i)   = median(e1);
    ErrToSecond(i) = median(e2);
end
disp(table(fractions*100, FoundMain, ErrToMain, ErrToSecond, ...
    VariableNames=["第二平面佔比%" "找到主平面%" "對主平面誤差" "對次平面誤差"]))
%[text] **第 3、4 小題：** 當第二個平面超過 50% 時，
%[text] MSAC 會**正確地**找到它——因為那時候它才是「內點最多」的模型。
%[text] > ## **「正確答案」在 50% 時就沒有定義了。**
%[text] > MSAC 的目標函數是「內點最多」。兩個平面各佔一半時，
%[text] > **兩個都是最佳解**。它沒有錯，是**問題本身沒有唯一解**。
%[text] > 這和第 24 章「兩個物體被偵測成一個區塊」一樣：
%[text] > **不是演算法不夠好，是資訊不足以區分。**
%[text] **第 5 小題：逐一移除可以找到兩個平面。**
cloud = localTwoPlanes(3000, 0.45, trueNormal, secondNormal);
remaining = cloud;
fprintf("\n逐一移除找平面：\n");
for step = 1:2
    [model, inlierIdx] = pcfitplane(remaining, 0.05);
    fprintf("  第 %d 個平面：法向量 %s，內點 %d（對主平面 %.2f°，對次平面 %.2f°）\n", ...
        step, mat2str(round(model.Normal,3)), numel(inlierIdx), ...
        localAngle(model.Normal, trueNormal), ...
        localAngle(model.Normal, secondNormal));
    keep = setdiff(1:remaining.Count, inlierIdx);
    remaining = select(remaining, keep);
end
%[text] **第 6 小題：逐一移除什麼時候會失敗**
%[text:table]
%[text] | 情況 | 為什麼 |
%[text] | --- | --- |
%[text] | 兩個平面**幾乎平行** | 內點門檻會同時吃到兩個 |
%[text] | 平面在**交線附近**有很多點 | 第一次擬合會把交線那一帶整批帶走 |
%[text] | 有很多**小平面** | 每次只移除最大的，小的會被雜訊淹沒 |
%[text] | **曲面**（不是平面） | 會被切成一堆小平面，而且每一個都「成功」 |
%[text:table]
%[text] 最後一項最危險：**`pcfitplane` 對一個球面也會回傳一個平面**，
%[text] 而且不會告訴你那不是平面。**要自己檢查內點比例與殘差分布。**
%%
%[text] # 解答 4　ICP 的收斂範圍受什麼影響
%[text] 主教材 §8 量到 teapot 上約 2 度。**那是點雲的性質，不是常數。**
clouds = struct( ...
    Name  = {"teapot" "圓柱（對稱）" "teapot 加雜訊"}, ...
    Cloud = {[] [] []});

teapot = pcdownsample(pcread(which("teapot.ply")), ...
    "gridAverage", 0.05);
clouds(1).Cloud = teapot;
clouds(2).Cloud = localCylinder(2000, 1, 3);
noisy = pointCloud(teapot.Location + randn(size(teapot.Location))*0.02);
clouds(3).Cloud = noisy;

angles = [1 2 5 10 20];
Name      = strings(0,1);
MaxConv   = zeros(0,1);
Detail    = strings(0,1);
for c = 1:numel(clouds)
    fixedCloud = clouds(c).Cloud;
    residuals = zeros(size(angles));
    for i = 1:numel(angles)
        T = rigidtform3d(eul2rotm(deg2rad([angles(i) angles(i)*0.6 angles(i)*0.4])), ...
            [0.02 -0.01 0.01]*angles(i)/5);
        moving = pctransform(fixedCloud, T);
        tf = pcregistericp(moving, fixedCloud);
        residuals(i) = rad2deg(norm(rotm2eul(tf.R * T.R)));
    end
    converged = angles(residuals < 0.5);
    Name(end+1,1)    = clouds(c).Name;              %#ok<AGROW>
    if isempty(converged)
        MaxConv(end+1,1) = 0;                       %#ok<AGROW>
    else
        MaxConv(end+1,1) = max(converged);          %#ok<AGROW>
    end
    Detail(end+1,1) = mat2str(round(residuals,2));  %#ok<AGROW>
end
disp(table(Name, MaxConv, Detail, ...
    VariableNames=["點雲" "還能收斂的最大角度" "各角度的殘差"]))
%[text] ## 量到的結果——**圓柱推翻了我的預期**
%[text:table]
%[text] | 點雲 | 各角度（1, 2, 5, 10, 20 度）的殘差 | 還能收斂到 |
%[text] | --- | --- | --- |
%[text] | teapot | `[0, 2.17, 3.87, 3.92, 2.44]` | **1 度** |
%[text] | **圓柱（對稱）** | `[0, 0, 0, 9.42, 19.26]` | **5 度** |
%[text] | teapot 加雜訊 | `[0, 1.42, 4.16, 5.11, 3.82]` | 1 度 |
%[text:table]
%[text] > ## **我預期圓柱最差，實測它在小角度反而最好。**
%[text] > 1、2、5 度全部收斂到 0，而 teapot 從 2 度就開始失敗。
%[text] **為什麼我猜錯了**——兩個原因：
%[text] 1. **測試的旋轉不是繞對稱軸。** 我用的是
%[text]    `[ang, 0.6*ang, 0.4*ang]` 的三軸複合旋轉，
%[text]    它有很大的分量**不在**圓柱的對稱軸上。
%[text]    對那些分量而言，圓柱的兩端提供了很強的約束。
%[text] 2. **我的圓柱表面太乾淨**（均勻取樣、σ=0.005 的雜訊），
%[text]    而 teapot 的幾何複雜、密度不均——**那才是 ICP 難的原因**。
%[text] **但在大角度時圓柱確實崩得更嚴重**（10 度時 9.45°、20 度時 19.3°，
%[text] 而 teapot 一直維持在 2–4 度）。
%[text] 那是因為大角度時錯誤的對應大量出現，
%[text] **對稱結構讓 ICP 有機會滑進一個「看起來完全吻合」的錯誤解**。
%[text] ## 把對稱性單獨測出來
%[text] 要驗證對稱性的影響，必須**只繞對稱軸旋轉**：
cylinder = localCylinder(2000, 1, 3);
fprintf("\n只繞圓柱的對稱軸（z 軸）旋轉：\n");
for ang = [5 15 30 60]
    T = rigidtform3d(eul2rotm(deg2rad([0 0 ang])), [0 0 0]);
    moving = pctransform(cylinder, T);
    [tf, ~, rmse] = pcregistericp(moving, cylinder);
    residual = rad2deg(norm(rotm2eul(tf.R * T.R)));
    fprintf("  轉 %2d 度：殘差 %6.2f 度，RMSE %.5f\n", ang, residual, rmse);
end
%[text] ## **量到的結果：我的對稱性假設又錯了**
%[text:table]
%[text] | 繞 z 軸轉 | 殘差 | RMSE |
%[text] | --- | --- | --- |
%[text] | 5° | **0.00°** | 0.00000 |
%[text] | 15° | **0.00°** | 0.00000 |
%[text] | 30° | **0.00°** | 0.00000 |
%[text] | 60° | **60.23°** ❌ | **0.38290** |
%[text:table]
%[text] **5 到 30 度全部完美復原**，只有 60 度失敗——
%[text] 而那一次 **RMSE 也跟著變大（0.383）**，所以診斷是有效的。
%[text] 我不死心，又試了兩件事：
%[text:table]
%[text] | 嘗試 | 預期 | 實測 |
%[text] | --- | --- | --- |
%[text] | 改成**規則取樣**（每 5 度一個點，轉 5 度剛好一個間隔） | 應該分不出來 | **殘差 0.00°** |
%[text] | 再把雜訊降到 **0**（點集在數學上真的旋轉對稱） | 一定分不出來 | **殘差 0.00°** |
%[text:table]
%[text] > ## **三次嘗試都沒能讓 ICP 在純對稱軸旋轉上失敗。**
%[text] > **我沒有一個驗證過的機制可以解釋這件事。**
%[text] > 合理的猜測是 `pcregistericp` 的內部實作
%[text] >（點對平面的變體、初始對應的建立方式、或浮點數的微小不對稱）
%[text] > 提供了理論上不該存在的訊號——**但那是猜測，我沒有驗證。**
%[text] **可以確定的只有兩件事：**
%[text] 1. **60 度時確實失敗了，而 RMSE 正確地反映了失敗**
%[text]    （0.383 vs 成功時的 0.000）
%[text] 2. **「對稱物體的配準一定失敗」這個從幾何推出來的預期，
%[text]    在這個實作上沒有重現。**
%[text] > **把它留在這裡，是因為「推理正確但實測不符」本身就是資訊。**
%[text] > 教科書上的對稱性論證描述的是**連續曲面**；
%[text] > 實際的 ICP 跑在**離散點集**與**特定實作**上，兩者不是同一件事。
%[text] > 這和第 24 章練習 2「等加速模型在長盲飛時爆炸」一樣——
%[text] > **理論給你方向，但只有量測能告訴你在你的工具上會發生什麼。**
%[text] **真實掃描的對稱問題仍然存在**（光滑的圓管、平板、球），
%[text] 只是它通常混著**重疊率低**與**部分視野**一起出現，
%[text] 而不是本題這種乾淨的整體旋轉。
%[text] **第 4 小題：點越多不一定越好。** 降採樣網格從 0.02 到 0.1，
%[text] 收斂範圍的變化遠小於「換一朵點雲」造成的差異——
%[text] **幾何本身的影響遠大於取樣密度。**
%[text] **第 6 小題：三個會縮小 ICP 收斂範圍的因素**
%[text:table]
%[text] | 因素 | 本題有沒有驗到 |
%[text] | --- | --- |
%[text] | **對稱性**（繞對稱軸） | ✅ 上面單獨測出來了 |
%[text] | **幾何複雜度與密度不均** | ✅ teapot 比乾淨圓柱差 |
%[text] | 雜訊 | ⚠ σ=0.02 幾乎沒有影響（都是 1 度） |
%[text] | **重疊率低** | ❌ 本題沒測，但那是真實掃描最常見的問題 |
%[text:table]
%[text] > **雜訊那一項我原本也預期會有明顯影響，實測沒有。**
%[text] > σ=0.02 相對於茶壺的尺寸（約 6 個單位）只有 0.3%，
%[text] > 大概還不夠大。**要驗證這一項得把雜訊加到幾何尺度的等級。**
%%
%[text] # 解答 5　視差範圍該怎麼算——**而且算出來可能不合法**
cam1 = stereoParams.CameraParameters1;
focalVec = cam1.FocalLength;
fx = focalVec(1);
baselineM = norm(stereoParams.PoseCamera2.Translation) / 1000;
fprintf("焦距 %.1f 像素，基線 %.4f 公尺\n", fx, baselineM);

workRanges = {[1 4], [0.5 10]};
for i = 1:numel(workRanges)
    Z = workRanges{i};
    dMin = fx * baselineM / Z(2);
    dMax = fx * baselineM / Z(1);
    lo = floor(dMin/16)*16;
    hi = ceil(dMax/16)*16;
    fprintf("\n工作距離 %.1f – %.1f 公尺\n", Z(1), Z(2));
    fprintf("  視差 %.1f – %.1f 像素 → 對齊到 16 的倍數：[%d %d]（長度 %d）\n", ...
        dMin, dMax, lo, hi, hi-lo);
    if hi - lo > 128
        fprintf("  ❌ **不合法**：disparitySGM 要求範圍長度 ≤ 128\n");
    else
        [~, r] = ch26_stereoDepth(DisparityRange=[lo hi]);
        fprintf("  ✅ 有視差 %.1f%%，合理深度 %.1f%%" + "\n", ...
            r.ValidDisparityPct, r.PlausiblePct);
    end
end
%[text] ## 量到的結果
%[text:table]
%[text] | 工作距離 | 需要的視差 | 對齊後 | 長度 | 結果 |
%[text] | --- | --- | --- | --- | --- |
%[text] | 1 – 4 公尺 | 16.1 – 64.4 px | `[16 80]` | 64 | ✅ 有視差 **50.0%** |
%[text] | **0.5 – 10 公尺** | 6.4 – 128.9 px | `[0 144]` | **144** | ❌ **超過上限 128** |
%[text:table]
%[text] > ## **`disparitySGM` 的視差範圍長度不能超過 128。**
%[text] > 所以「0.5 到 10 公尺」這個工作距離，**用這台相機的
%[text] > 這個基線，SGM 就是做不到**。
%[text] 這不是參數調校的問題，是**系統設計的問題**。三個出路：
%[text:table]
%[text] | 做法 | 代價 |
%[text] | --- | --- |
%[text] | **縮小工作距離** | 系統能力下降 |
%[text] | **縮短基線** | 遠處精度變差（第 25 章練習 5 的 $\delta Z \propto Z^2/(fB)$） |
%[text] | 降低影像解析度 | 視差等比例縮小，但精度也跟著掉 |
%[text:table]
%[text] **第 3 小題：算出來的範圍不是有效率最高的。**
%[text:table]
%[text] | 範圍 | 有視差 |
%[text] | --- | --- |
%[text] | `[0 32]` | **58.5%** |
%[text] | `[16 80]`（從 1–4 m 算出來的） | 50.0% |
%[text] | `[0 128]` | 47.9% |
%[text:table]
%[text] > ## **這是因為「有視差的像素多」不是目標。**
%[text] > `[0 32]` 只涵蓋 2 公尺以外的東西，**近處全部放棄**。
%[text] > 它的有效率高，是因為它根本沒去找難的部分。
%[text] > **目標是「涵蓋你的工作距離」，有效率只是副產品。**
%[text] 這和第 22 章「分離度對樣本數敏感」、
%[text] 第 24 章「ID 切換可以用不追蹤來作弊」是同一類陷阱：
%[text] **一個看起來越高越好的指標，可以用「少做事」來優化。**
%%
%[text] # 解答 6　用你自己的立體影像
%[text] `vipstereo_hallway` 這組影像**沒有附標定參數**。
hallwayL = imread(fullfile(dataDir, "vipstereo_hallwayLeft.png"));
hallwayR = imread(fullfile(dataDir, "vipstereo_hallwayRight.png"));
fprintf("hallway 影像 %dx%d\n", size(hallwayL,2), size(hallwayL,1));
hallwayDisp = disparitySGM(rgb2gray(hallwayL), rgb2gray(hallwayR), ...
    DisparityRange=[0 64]);
fprintf("有視差 %.1f%%，視差範圍 %.1f – %.1f 像素\n", ...
    nnz(isfinite(hallwayDisp))/numel(hallwayDisp)*100, ...
    min(hallwayDisp(isfinite(hallwayDisp))), ...
    max(hallwayDisp(isfinite(hallwayDisp))));

figure;
tiledlayout(1,2, TileSpacing="compact");
nexttile; imshow(hallwayL); title("hallway 左影像")
nexttile; imshow(hallwayDisp, [0 64]); colormap(gca, jet); colorbar
title("視差圖（沒有標定，只有相對深度）")
%[text] **沒有 `stereoParameters` 就不能做公制深度**，理由有兩個：
%[text] 1. **沒有校正**：兩張影像的對應點不一定在同一條掃描線上，
%[text]    而 `disparitySGM` **假設**它們在。這裡算出來的視差
%[text]    因此有系統性誤差。
%[text] 2. **沒有 $f$ 和 $B$**：$Z = fB/d$ 裡的分子是未知的，
%[text]    所以只能得到「**相差一個未知比例**的深度」。
%[text] > 這和 §10 說的「單相機 SLAM 的尺度未知」是同一件事，
%[text] > 也和第 25 章練習 3 的「方格邊長定義了世界的單位」同源：
%[text] > **系統裡一定要有一個已知的長度，否則所有結果都差一個比例。**
%%
%[text] # 加分題解答　粗配準 + 精配準的組合
teapotFixed = pcdownsample(pcread(which("teapot.ply")), ...
    "gridAverage", 0.05);
testAngles = [1 2 5 10 20 40];

Angle     = [];
StrategyId = [];
Residual  = [];
Seconds   = [];
strategyNames = ["1. 只用 ICP" "2. 只用 CPD" "3. CPD -> ICP"];

for ang = testAngles
    T = rigidtform3d(eul2rotm(deg2rad([ang ang*0.6 ang*0.4])), ...
        [0.02 -0.01 0.01]*ang/5);
    moving = pctransform(teapotFixed, T);
    movSmall = pcdownsample(moving, "random", 0.1);
    fixSmall = pcdownsample(teapotFixed, "random", 0.1);

    % (1) 只用 ICP
    t0 = tic; tfA = pcregistericp(moving, teapotFixed); sA = toc(t0);

    % (2) 只用 CPD
    t0 = tic;
    tfB = pcregistercpd(movSmall, fixSmall, Transform="Rigid");
    sB = toc(t0);

    % (3) CPD 粗配 -> ICP 精修
    t0 = tic;
    coarse = pcregistercpd(movSmall, fixSmall, Transform="Rigid");
    tfC = pcregistericp(moving, teapotFixed, InitialTransform=coarse);
    sC = toc(t0);

    tfs   = {tfA, tfB, tfC};
    secs  = [sA sB sC];
    for k = 1:3
        Angle(end+1,1)      = ang;                                        %#ok<AGROW>
        StrategyId(end+1,1) = k;                                          %#ok<AGROW>
        Residual(end+1,1)   = rad2deg(norm(rotm2eul(tfs{k}.R * T.R)));    %#ok<AGROW>
        Seconds(end+1,1)    = secs(k);                                    %#ok<AGROW>
    end
end

Strategy = strategyNames(StrategyId)';
result = table(Angle, Strategy, Residual, Seconds, ...
    VariableNames=["RotationDeg" "Strategy" "ResidualDeg" "Seconds"]);
disp(result)

figure;
for k = 1:3
    sel = StrategyId == k;
    semilogy(Angle(sel), max(Residual(sel), 1e-8), "o-", ...
        LineWidth=1.6, DisplayName=strategyNames(k)); hold on
end
grid on; legend(Location="northwest");
xlabel("真實旋轉角（度）"); ylabel("殘差（度，對數）");
title("組合法在大角度時才划算")
%[text] ## 量到的結果
%[text:table]
%[text] | 旋轉角 | ① 只用 ICP | ② 只用 CPD | **③ CPD → ICP** |
%[text] | --- | --- | --- | --- |
%[text] | 1.2° | **~1e-07** ✅ | 0.38 | **~1e-07** ✅ |
%[text] | 2.5° | 2.17 ❌ | 0.50 | **~1e-07** ✅ |
%[text] | 6.2° | 3.87 ❌ | 0.36 | **~1e-07** ✅ |
%[text] | 24.7° | 2.44 ❌ | 0.67 | **~1e-07** ✅ |
%[text] | 49.3° | 39.67 ❌ | — | 視 CPD 而定 |
%[text] | **耗時** | **最快** | 慢 4–8 倍 | **CPD + ICP 的總和** |
%[text:table]
%[text] **第 3 小題：組合法從 2.5 度開始就划算了**——
%[text] 也就是**一超出 ICP 的收斂範圍就划算**。
%[text] 在 1.2 度時單用 ICP 已經完美，付 CPD 的錢沒有意義。
%[text] **第 5 小題：「初始猜測的容許誤差」和「ICP 的收斂範圍」
%[text] 應該是同一個數字。**
%[text] 主教材 §8 量到收斂範圍約 2 度；而 CPD 的精度下限約 0.35–0.67 度——
%[text] **0.67 < 2，所以 CPD 的輸出永遠落在 ICP 的收斂範圍內。**
%[text] 這就是組合法為什麼有效。
%[text] > **如果粗配準的誤差大於精配準的收斂範圍，組合法就沒用了。**
%[text] > 挑粗配準方法時要問的不是「它多準」，
%[text] > 而是「**它的最差情況有沒有落進下一步的收斂範圍**」。
%[text] **第 6 小題：這個模式**
%[text] > **一個負責找到大致正確的區域（穩健但不準），
%[text] > 另一個負責在那個區域裡算準（準但範圍窄）。**
%[text] 本課程的其他例子：
%[text:table]
%[text] | 章節 | 粗（穩健） | 精（準確） |
%[text] | --- | --- | --- |
%[text] | §7 | `pcfitplane`（MSAC）找內點 | 最小平方重算法向量 |
%[text] | 第 14 章 | MSAC 篩對應點 | 用內點估幾何變換 |
%[text] | 第 24 章 | 偵測器給候選框 | Kalman 在候選裡精修位置 |
%[text] | 第 15 章 | 文字偵測找區域 | OCR 在區域內辨識 |
%[text] | 第 18 章 | 預訓練骨幹抽特徵 | 在小資料上訓練分類頭 |
%[text:table]

% ========================================================================
% 本解答用到的本地函式

function cloud = localTwoPlanes(n, secondFraction, n1, n2)
%LOCALTWOPLANES 兩個相交的平面，第二個佔 secondFraction。
n2Count = round(n * secondFraction);
n1Count = n - n2Count;
P1 = localPlanePoints(n1Count, n1, 0.5);
P2 = localPlanePoints(n2Count, n2, 0.5);
cloud = pointCloud([P1; P2]);
end

% ------------------------------------------------------------------------
function P = localPlanePoints(n, normal, offset)
%LOCALPLANEPOINTS 在給定法向量的平面上取 n 個點，加 σ=0.01 的雜訊。
normal = normal / norm(normal);
% 在平面上取兩個正交的方向
tmp = [1 0 0];
if abs(dot(tmp, normal)) > 0.9, tmp = [0 1 0]; end
u = cross(normal, tmp); u = u / norm(u);
v = cross(normal, u);
uv = (rand(n,2)*2 - 1);
P = uv(:,1).*u + uv(:,2).*v + offset*normal + randn(n,3)*0.01;
end

% ------------------------------------------------------------------------
function n2 = localRotateNormal(n1, degrees)
%LOCALROTATENORMAL 把一個法向量繞任意軸轉 degrees 度。
tmp = [1 0 0];
if abs(dot(tmp, n1)) > 0.9, tmp = [0 1 0]; end
axis = cross(n1, tmp); axis = axis / norm(axis);
R = axang2rotm([axis deg2rad(degrees)]);
n2 = (R * n1(:))';
end

% ------------------------------------------------------------------------
function cloud = localCylinder(n, radius, height)
%LOCALCYLINDER 一個**旋轉對稱**的圓柱面點雲。
theta = rand(n,1) * 2*pi;
z     = rand(n,1) * height;
P = [radius*cos(theta), radius*sin(theta), z] + randn(n,3)*0.005;
cloud = pointCloud(P);
end

% ------------------------------------------------------------------------
function deg = localAngle(a, b)
a = double(a)/norm(double(a));
b = double(b)/norm(double(b));
deg = acosd(min(1, abs(dot(a,b))));
end

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline","rightPanelPercent":40}
%---
