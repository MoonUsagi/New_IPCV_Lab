%[text] # 第 07 章　幾何轉換與影像配準
%[text] IPCV\_Lab 課程教材　｜　MATLAB R2026b　｜　難度：\[基礎\]　｜　建議時數：2 小時
%[text:tableOfContents]{"heading":"本章目錄"}
%[text] ## 學習目標
%[text] 完成本章後，你應該能夠：
%[text] 1. 說明各種幾何轉換模型的自由度，並依問題選擇正確的模型
%[text] 2. 用空間參考物件控制轉換後影像的座標與範圍
%[text] 3. 完成兩張影像的自動配準，並知道**為什麼強度式配準需要初始猜測**
%[text] 4. 處理非剛性形變
%[text] 5. 量化配準的好壞 \
%[text] ## 前置知識
%[text] 第 01 章（影像座標）。本章與前六章的差別：
%[text] 前六章都在改變**像素的值**，本章開始改變**像素的位置**。
%[text] ## 環境需求
assert(exist("checkEnvironment","file") == 2, ...
    "請先切換到課程根目錄並執行 ipcvSetup，再回來執行本章。");
checkEnvironment(Chapters="07", Verbose=false);
disp("環境檢查通過。")
%%
%[text] # 1. 轉換模型與自由度
%[text] 幾何轉換把來源座標 $(x,y)$ 映射到目標座標 $(x',y')$。
%[text] 不同模型能表達的變化不同，**自由度**（DOF）決定了你需要多少組對應點才能求解。
%[text:table]
%[text] | 模型 | MATLAB 物件 | 自由度 | 能表達 | 保持 |
%[text] | --- | --- | --- | --- | --- |
%[text] | 平移 | `transltform2d` | 2 | 移動 | 形狀、大小、角度 |
%[text] | 剛體 | `rigidtform2d` | 3 | 移動＋旋轉 | 形狀、大小 |
%[text] | 相似 | `simtform2d` | 4 | ＋等比例縮放 | 形狀（角度） |
%[text] | 仿射 | `affinetform2d` | 6 | ＋非等比縮放、剪切 | 平行線仍平行 |
%[text] | 投影 | `projtform2d` | 8 | ＋透視變形 | 直線仍是直線 |
%[text:table]
%[text] **選模型的原則：用能解決問題的最簡單模型。**
%[text] 自由度越高越容易過度擬合——在只有平移的場景用投影模型，
%[text] 雜訊會讓你得到一個扭曲的結果。
%[text] **注意命名**：R2022b 起 MATLAB 改用 `*tform2d` 系列
%[text] （`affinetform2d`），取代舊的 `affine2d`。兩者的**矩陣慣例不同**——
%[text] 新的用後乘（row vector × matrix 的轉置形式），舊的用前乘。
%[text] 混用會得到轉置或反向的結果，是升級舊程式最常見的 bug。
I = im2double(imread("cameraman.tif"));
Rin = imref2d(size(I));

transforms = { ...
    "平移 (30,20)",   transltform2d(30, 20); ...
    "旋轉 25°",       rigidtform2d(25, [0 0]); ...
    "相似 0.7×,15°",  simtform2d(0.7, 15, [40 20]); ...
    "仿射（剪切）",    affinetform2d([1 0.3 0; 0 1 0; 0 0 1]); ...
    "投影（透視）",    projtform2d([1 0.1 0; 0.05 1 0; 0.0008 0.0005 1])};

warped = cellfun(@(tf) imwarp(I, tf, OutputView=Rin), transforms(:,2), UniformOutput=false);

figure
montage([{I}; warped]', Size=[2 3])
title("原圖 ｜ " + strjoin(string(transforms(:,1))', " ｜ "))
%%
%[text] # 2. 空間參考：`OutputView` 為什麼重要
%[text] `imwarp` 預設會**自動調整輸出範圍**，讓轉換後的影像完整裝得下。
%[text] 這通常不是你要的——尤其是要疊圖或比較時。
tf = simtform2d(1.3, 30, [0 0]);

autoOut  = imwarp(I, tf);                    % 預設：自動擴張
fixedOut = imwarp(I, tf, OutputView=Rin);    % 固定：與輸入同尺寸同座標

fprintf("原圖尺寸         %s\n", mat2str(size(I)));
fprintf("自動輸出尺寸     %s  <- 變大了\n", mat2str(size(autoOut)));
fprintf("指定 OutputView  %s  <- 與原圖一致\n", mat2str(size(fixedOut)));

figure
montage({I, autoOut, fixedOut}, Size=[1 3])
title("原圖 ｜ 自動輸出範圍（尺寸變了）｜ 指定 OutputView（可直接比較）")
%[text] **規則**：只要你之後要把結果與另一張影像**比較、相減或疊圖**，
%[text] 就必須指定 `OutputView`，否則兩張影像的座標系不同，比較沒有意義。
%%
%[text] ## 2.1 R2026a：`affineOutputView` 支援空間參考物件
%[text] `affineOutputView` 幫你算出「剛好裝得下轉換結果」的輸出範圍。
%[text] R2026a 起它**接受空間參考物件作為輸入**，讓不在內建座標系
%[text] （intrinsic coordinates）的影像也能正確處理。
Rout = affineOutputView(size(I), tf, BoundsStyle="centerOutput");
centered = imwarp(I, tf, OutputView=Rout);

fprintf("centerOutput 輸出尺寸 %s\n", mat2str(size(centered)));
fprintf("世界座標 X 範圍 [%.1f %.1f]，Y 範圍 [%.1f %.1f]\n", ...
    Rout.XWorldLimits, Rout.YWorldLimits);

figure
imshow(centered, Rout)
title("centerOutput：轉換後的影像置中")
%[text] 三種 `BoundsStyle` 的實際差別：
for bs = ["centerOutput" "followOutput" "sameAsInput"]
    R = affineOutputView(size(I), tf, BoundsStyle=bs);
    fprintf("%-14s 尺寸 %-12s X[%6.0f %6.0f]  Y[%6.0f %6.0f]\n", ...
        bs, mat2str(R.ImageSize), R.XWorldLimits, R.YWorldLimits);
end
%[text:table]
%[text] | BoundsStyle | 尺寸 | 用途 |
%[text] | --- | --- | --- |
%[text] | `"centerOutput"` | **與輸入相同** | 保持畫布大小，但視窗移到轉換結果的中心。適合「不想改變輸出尺寸，但要看到主要內容」 |
%[text] | `"followOutput"` | **放大到裝得下全部** | 與 `imwarp` 不給 `OutputView` 的預設行為相同 |
%[text] | `"sameAsInput"` | 與輸入相同 | 座標也與輸入相同，等同 `OutputView=imref2d(size(I))` |
%[text:table]
%[text] 注意 `"centerOutput"` **不會**放大輸出——它只是把同樣大小的視窗
%[text] 移到轉換結果的中心，超出邊界的部分仍然被裁掉。
%[text] 要完整保留內容請用 `"followOutput"`。
%%
%[text] # 3. 配準：讓兩張影像對齊
%[text] **配準**（registration）是找出一個轉換，把「待配準影像」對齊到「參考影像」。
%[text] 應用遍布各處：醫療影像的術前術後比對、衛星影像拼接、
%[text] 產線上的定位校正、第 14 章的影像拼接。
%[text] 為了能**驗證**配準有多準，我們先用一個**已知答案**的例子：
%[text] 對同一張影像套用已知的轉換，再試著把它還原回去。
trueAngle = 23;
trueScale = 0.85;
trueShift = [15 -10];

tformTrue = simtform2d(trueScale, trueAngle, trueShift);
moved = imwarp(I, tformTrue, OutputView=Rin);

figure
imshowpair(I, moved, "montage")
title("參考影像 ｜ 待配準影像（已知：旋轉 23°、縮放 0.85）")

fprintf("真實轉換：旋轉 %g°，縮放 %g，平移 (%g, %g)\n", trueAngle, trueScale, trueShift);
fprintf("未配準時 PSNR %.2f dB\n", psnr(moved, I));
%%
%[text] ## 3.1 方法一：相位相關 `imregcorr`
%[text] 相位相關在**頻域**工作（呼應第 05 章）。它利用一個性質：
%[text] 空間域的平移，在頻域只是相位的改變，振幅完全不變。
%[text] 這讓它能一次算出平移量，不需要迭代搜尋。
%[text] 配合對數極座標轉換，還能同時求出旋轉與縮放。
tfCorr = imregcorr(moved, I);
recCorr = imwarp(moved, tfCorr, OutputView=Rin);

% 從轉換矩陣反推出角度與縮放
angleOf = @(tf) rad2deg(atan2(tf.A(2,1), tf.A(1,1)));
scaleOf = @(tf) hypot(tf.A(1,1), tf.A(2,1));

fprintf("imregcorr 回復：旋轉 %.2f°（真值 %g），縮放 %.4f（真值 %g）\n", ...
    -angleOf(tfCorr), trueAngle, 1/scaleOf(tfCorr), trueScale);
fprintf("配準後 PSNR %.2f dB\n", psnr(recCorr, I));
%[text] 幾乎完全命中。**`imregcorr` 的優點是快且不需要初始猜測**，
%[text] 缺點是只支援平移／剛體／相似三種模型，且要求兩張影像的**內容大致相同**。
%%
%[text] ## 3.2 方法二：強度式最佳化 `imregtform`
%[text] 強度式配準把配準當成**最佳化問題**：調整轉換參數，讓某個相似度指標最大。
%[text] 它支援更多模型（含仿射），也能處理不同模態的影像。
%[text] 但它有一個關鍵弱點——**它是局部最佳化，需要好的起點**。
[optimizer, metric] = imregconfig("monomodal");

tfIntensity = imregtform(moved, I, "similarity", optimizer, metric);
recIntensity = imwarp(moved, tfIntensity, OutputView=Rin);

fprintf("imregtform 回復：旋轉 %.2f°（真值 %g），縮放 %.4f（真值 %g）\n", ...
    -angleOf(tfIntensity), trueAngle, 1/scaleOf(tfIntensity), trueScale);
fprintf("配準後 PSNR %.2f dB\n", psnr(recIntensity, I));
%[text] **它失敗了**——回復出來的旋轉只有 1.8 度左右，離真值 23 度差很遠。
%[text] 原因是預設的初始轉換是「單位矩陣」（完全不動），
%[text] 而 23 度的旋轉離這個起點太遠，最佳化器陷在局部極值出不來。
%%
%[text] ## 3.3 正確做法：兩者串接
%[text] 官方建議的做法是：**先用 `imregcorr` 取得粗略的初始轉換，
%[text] 再用 `imregtform` 精修**。
tfCombined = imregtform(moved, I, "similarity", optimizer, metric, ...
    InitialTransformation=tfCorr);
recCombined = imwarp(moved, tfCombined, OutputView=Rin);

results = { ...
    "未配準",              moved,        NaN,               NaN; ...
    "imregcorr",           recCorr,      -angleOf(tfCorr),      1/scaleOf(tfCorr); ...
    "imregtform（單獨）",   recIntensity, -angleOf(tfIntensity), 1/scaleOf(tfIntensity); ...
    "兩者串接",            recCombined,  -angleOf(tfCombined),  1/scaleOf(tfCombined)};

fprintf("\n%-22s %10s %10s %12s\n", "方法", "旋轉", "縮放", "PSNR");
for k = 1:size(results,1)
    fprintf("%-22s %9.2f° %10.4f %11.2f dB\n", results{k,1}, results{k,3}, results{k,4}, ...
        psnr(results{k,2}, I));
end
fprintf("%-22s %9.2f° %10.4f\n", "（真值）", trueAngle, trueScale);

figure
montage(results(:,2)', Size=[2 2])
title("未配準 ｜ imregcorr ｜ imregtform 單獨（失敗）｜ 兩者串接")

figure
imshowpair(I, recCombined)
title("配準結果疊圖（綠＝參考，洋紅＝配準後）")
%[text] **這一節是本章最重要的實務知識**：
%[text] 強度式配準單獨使用時很容易失敗，而且**失敗得很安靜**——
%[text] 它不會報錯，只會回傳一個錯誤的轉換。
%[text] 一定要給它好的起點，並且**驗證結果**。
%%
%[text] # 4. 多模態配準
%[text] 前面兩張影像是同一張圖，亮度關係一致。
%[text] 現實中常要配準**不同感測器、不同時間**拍的影像，
%[text] 它們的亮度沒有直接對應關係——這叫**多模態**配準。
ortho  = imread("westconcordorthophoto.png");   % 正射影像（參考）
aerial = im2gray(imread("westconcordaerial.png"));  % 空拍影像（待配準）

figure
imshowpair(ortho, aerial, "montage")
title("正射影像（參考）｜ 空拍影像（待配準）— 亮度關係完全不同")

Rortho = imref2d(size(ortho));
tfMM = imregcorr(aerial, ortho);
recMM = imwarp(aerial, tfMM, OutputView=Rortho);

[optMM, metMM] = imregconfig("multimodal");
optMM.InitialRadius = optMM.InitialRadius / 3.5;   % 預設值容易發散，調小
optMM.MaximumIterations = 300;

tfMM2 = imregtform(aerial, ortho, "similarity", optMM, metMM, ...
    InitialTransformation=tfMM);
recMM2 = imwarp(aerial, tfMM2, OutputView=Rortho);

figure
tiledlayout(1,3)
nexttile; imshowpair(ortho, imresize(aerial, size(ortho))); title("未配準")
nexttile; imshowpair(ortho, recMM);  title("imregcorr")
nexttile; imshowpair(ortho, recMM2); title("再用 imregtform 精修")
%[text] **`imregconfig("multimodal")` 與 `"monomodal"` 的差別**：
%[text:table]
%[text] | | monomodal | multimodal |
%[text] | --- | --- | --- |
%[text] | 相似度指標 | 均方差 | **互資訊**（mutual information） |
%[text] | 最佳化器 | 規則步長梯度下降 | 演化式（One-plus-one evolutionary） |
%[text] | 適用 | 同一感測器、亮度可比 | 不同感測器、不同模態 |
%[text] | 穩定性 | 較穩定 | **容易發散，常要調小 `InitialRadius`** |
%[text:table]
%[text] 上面那行 `optMM.InitialRadius = optMM.InitialRadius / 3.5;`
%[text] 不是隨便寫的——多模態配準用預設值發散是常態，
%[text] MATLAB 官方範例也是這樣調。看到「optimization diverged」警告就往這裡調。
%%
%[text] # 5. 控制點配準
%[text] 當自動配準失敗（內容差異太大、變形太複雜），就手動指定**對應點**。
%[text] `cpselect` 提供互動介面；`fitgeotform2d` 從對應點求出轉換。
interactive = false;    % 改成 true 以開啟 cpselect

if interactive
    cpselect(aerial, ortho)
end
%[text] 為了能**驗證殘差的意義**，這裡回到已知答案的合成案例。
%[text] 先取幾個點，用真實轉換算出它們的對應位置——這模擬「標得很準」的情況：
srcPoints = [ 50  50;  200  60;   60 200;  190 190;  128 128];
dstPoints = transformPointsForward(tformTrue, srcPoints);

tfCP = fitgeotform2d(dstPoints, srcPoints, "similarity");
residuals = vecnorm(transformPointsForward(tfCP, dstPoints) - srcPoints, 2, 2);

fprintf("標得很準時：\n");
fprintf("  各點殘差 %s\n", mat2str(round(residuals', 3)));
fprintf("  平均 %.4f 像素，最大 %.4f 像素\n", mean(residuals), max(residuals));
fprintf("  回復旋轉 %.2f°（真值 %g）\n\n", -angleOf(tfCP), trueAngle);
%[text] 殘差接近零，回復的角度也正確。
%[text] 現在**故意把其中一點標錯 25 像素**，看殘差怎麼反應：
badPoints = dstPoints;
badPoints(3,:) = badPoints(3,:) + [25 -18];      % 第 3 點標錯

tfBad = fitgeotform2d(badPoints, srcPoints, "similarity");
residualsBad = vecnorm(transformPointsForward(tfBad, badPoints) - srcPoints, 2, 2);

fprintf("有一點標錯時：\n");
fprintf("  各點殘差 %s\n", mat2str(round(residualsBad', 2)));
fprintf("  平均 %.2f 像素，最大 %.2f 像素\n", mean(residualsBad), max(residualsBad));
fprintf("  回復旋轉 %.2f°（真值 %g）  <- 被拉歪了\n", -angleOf(tfBad), trueAngle);

[~, worstIdx] = max(residualsBad);
fprintf("  殘差最大的是第 %d 點——正是標錯的那一點\n", worstIdx);

figure
bar(categorical("點" + (1:numel(residualsBad))'), [residuals residualsBad])
legend("全部標準確", "第 3 點標錯", Location="northwest")
ylabel("殘差（像素）"); title("控制點殘差診斷"); grid on
%[text] **殘差是控制點配準的品質指標，而且它會指出是哪一點有問題。**
%[text] 注意錯誤被「分攤」到所有點上了——最小平方擬合會為了遷就那個壞點，
%[text] 把整個轉換拉歪，讓其他好點也產生殘差。
%[text] 所以**不要只看平均殘差**，要看**逐點殘差**：
%[text] 有一點特別突出就刪掉它重標，不要硬撐。
%[text] 這也是為什麼要給 4 點以上——2 點剛好求解，殘差恆為零，你什麼都看不出來。
%[text] **點數的選擇**：至少要達到模型的自由度除以 2
%[text] （每個點提供 2 個方程式）。相似轉換 4 個自由度，最少 2 點；
%[text] 但**實務上要給 4 點以上**，多出來的點才能算殘差、才知道準不準。
%%
%[text] # 6. 非剛性配準
%[text] 前面所有轉換都是**全域**的——整張影像套用同一個矩陣。
%[text] 有些形變是**局部**的：軟組織的變形、紙張的皺褶、鏡頭的局部畸變。
%[text] 這時需要**非剛性**（deformable）配準，它為**每個像素**求一個位移向量。
fixedImg  = im2double(imread("cameraman.tif"));

% 製造一個局部形變
[gx, gy] = meshgrid(1:size(fixedImg,2), 1:size(fixedImg,1));
cx = 128; cy = 128;
r = hypot(gx - cx, gy - cy);
amp = 12 * exp(-(r.^2) / (2*60^2));          % 中央附近最強的徑向位移
movingImg = imwarp(fixedImg, cat(3, amp .* (gx-cx)./max(r,1), ...
                                     amp .* (gy-cy)./max(r,1)));

[displacement, registered] = imregdemons(movingImg, fixedImg, [100 50 25], ...
    AccumulatedFieldSmoothing=1.3, DisplayWaitbar=false);

fprintf("未配準  PSNR %.2f dB\n", psnr(movingImg, fixedImg));
fprintf("demons  PSNR %.2f dB\n", psnr(registered, fixedImg));
fprintf("位移場大小 %s（每個像素一個 2D 向量）\n", mat2str(size(displacement)));

figure
tiledlayout(2,2)
nexttile; imshowpair(fixedImg, movingImg);  title("配準前")
nexttile; imshowpair(fixedImg, registered); title("demons 配準後")
nexttile; imshow(mat2gray(vecnorm(displacement, 2, 3))); title("位移量大小")
nexttile
step = 12;
quiver(gx(1:step:end,1:step:end), gy(1:step:end,1:step:end), ...
       displacement(1:step:end,1:step:end,1), displacement(1:step:end,1:step:end,2))
axis ij image; title("位移向量場")
%[text] **非剛性配準的風險**：自由度極高（每個像素 2 個），
%[text] 它幾乎**總能**把來源影像扭成參考影像的樣子——即使兩者根本不該對齊。
%[text] `AccumulatedFieldSmoothing` 就是用來限制形變的平滑度，避免過度扭曲。
%[text] **量測用途要特別小心**：非剛性配準會改變幾何關係，
%[text] 配準後的影像不能再拿來量尺寸。
%%
%[text] # 7. Registration Estimator APP
%[text] MATLAB 提供互動式的配準 APP，可以並排比較多種方法與參數，
%[text] 滿意後匯出程式碼——又是第 02 章的五步驟工作流。
if interactive
    registrationEstimator(aerial, ortho)
end
%[text] 這個 APP 特別適合**還不知道該用哪種方法**的時候：
%[text] 它會同時跑 feature-based、intensity-based、phase-correlation 三類，
%[text] 讓你直接看哪個有效，再匯出對應的程式碼。
%%
%[text] # 8. 常見陷阱
%[text:table]
%[text] | 陷阱 | 症狀 | 正確做法 |
%[text] | --- | --- | --- |
%[text] | 混用 `affine2d` 與 `affinetform2d` | 結果轉置或方向相反 | R2022b 起統一用 `*tform2d`；矩陣慣例不同 |
%[text] | 沒指定 `OutputView` | 輸出尺寸變了，無法與參考影像比較 | 要比較就一定要指定 |
%[text] | 只用 `imregtform` | **安靜地失敗**，回傳錯誤的轉換 | 先用 `imregcorr` 取得初始值 |
%[text] | 多模態配準用預設 `InitialRadius` | 「optimization diverged」警告 | 調小（除以 3～4） |
%[text] | 選了超出需要的轉換模型 | 過度擬合，結果扭曲 | 用能解決問題的**最簡單**模型 |
%[text] | 控制點只給最低數量 | 沒有殘差可算，不知道準不準 | 給 4 點以上 |
%[text] | 配準後直接拿去量測 | 非剛性配準已改變幾何關係 | 量測要用原始影像，或只用剛體／相似轉換 |
%[text] | 沒有驗證配準結果 | 錯的轉換也會產生一張「看起來像」的影像 | 用已知答案測試，或看 `imshowpair` 疊圖 |
%[text:table]
%%
%[text] # 9. 本章小結
%[text] - 選轉換模型的原則：**能解決問題的最簡單模型**
%[text] - 要比較或疊圖就必須指定 `OutputView`
%[text] - **強度式配準需要好的初始猜測**。本章實測：單獨使用時回復出
%[text] 1.8° 而不是 23°，串接 `imregcorr` 後準確到 23.00°
%[text] - 多模態配準用互資訊指標，且**常需調小 `InitialRadius`**
%[text] - 非剛性配準幾乎總能「對齊」，所以更要小心它是不是對錯了 \
%[text] ## 函式速查
%[text:table]
%[text] | 函式 | 用途 | 備註 |
%[text] | --- | --- | --- |
%[text] | `imwarp` | 套用幾何轉換 | **記得 `OutputView`** |
%[text] | `transltform2d` `rigidtform2d` `simtform2d` `affinetform2d` `projtform2d` | 轉換物件 | 取代舊的 `affine2d` 等 |
%[text] | `imref2d` | 空間參考物件 | 定義影像的世界座標 |
%[text] | `affineOutputView` | 計算輸出範圍 | R2026a 支援空間參考輸入 |
%[text] | `imregcorr` | 相位相關配準 | 快、免初始值；R2024b 起演算法改良 |
%[text] | `imregtform` `imregister` | 強度式配準 | **一定要給初始轉換** |
%[text] | `imregconfig` | 取得最佳化器與指標 | `"monomodal"` / `"multimodal"` |
%[text] | `imregdemons` | 非剛性配準 | 注意過度扭曲 |
%[text] | `cpselect` `fitgeotform2d` | 控制點配準 | 用殘差判斷品質 |
%[text] | `transformPointsForward` `transformPointsInverse` | 轉換座標點 | 算殘差用 |
%[text] | `registrationEstimator` | 互動式配準 APP | 可匯出程式碼 |
%[text] | `imshowpair` | 疊圖比較 | 驗證配準的第一步 |
%[text:table]
%%
%[text] # 10. 練習
%[text] 開啟 `exercise/Ch07_Exercise.m`，完成五題。解答在 `Ch07_Solution.m`。
%%
%[text] # 11. 延伸閱讀與下一章
%[text] - [Geometric Transformations](https://www.mathworks.com/help/images/geometric-transformations.html)
%[text] - [Image Registration](https://www.mathworks.com/help/images/image-registration.html)
%[text] - **下一章**：第 08 章　傳統影像分割——Part I 到此結束，Part II 開始處理「把影像切成有意義的區域」 \

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline","rightPanelPercent":40}
%---
