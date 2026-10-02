%[text] # 第 10 章　練習解答
assert(exist("ch10_autoCircles","file") == 2, ...
    "請先切換到課程根目錄並執行 ipcvSetup。");
hasYOLOCircles = exist("imfindcirclesYOLO","file") == 2;
rng(0);
I = im2double(imread("circuit.tif"));
methods = ["Sobel" "Prewitt" "Roberts" "log" "Canny"];
%%
%[text] # 解答 1：設計一個公平的比較（模糊耐受度）
sigmas = 0:0.5:3;
edgeCounts = zeros(numel(methods), numel(sigmas));

% 關鍵：門檻固定為「乾淨影像的自動門檻」，否則自動門檻會補償掉差異
fixedThresholds = cell(1, numel(methods));
for m = 1:numel(methods)
    [~, fixedThresholds{m}] = edge(I, methods(m));
end

for s = 1:numel(sigmas)
    if sigmas(s) == 0
        blurred = I;
    else
        blurred = imgaussfilt(I, sigmas(s));
    end
    for m = 1:numel(methods)
        edgeCounts(m,s) = nnz(edge(blurred, methods(m), fixedThresholds{m}));
    end
end

figure
plot(sigmas, edgeCounts', "-o", LineWidth=1.5)
legend(methods, Location="northeast")
xlabel("高斯模糊 sigma"); ylabel("邊緣像素數（固定門檻）")
title("邊緣算子對模糊的耐受度"); grid on

% sigma=3 時所有小核算子都歸零，分不出高下。用 sigma=1 才看得出差異。
sigma1Col = find(sigmas == 1, 1);

fprintf("%-10s %10s %10s %14s %12s\n", "算子", "sigma=0", "sigma=1", "sigma=1 保留率", "sigma=3");
for m = 1:numel(methods)
    fprintf("%-10s %10d %10d %13.1f%% %12d\n", methods(m), ...
        edgeCounts(m,1), edgeCounts(m,sigma1Col), ...
        100*edgeCounts(m,sigma1Col)/edgeCounts(m,1), edgeCounts(m,end));
end
%[text] **注意 sigma=3 那一欄**：除了 Canny 之外全部歸零。
%[text] 這種「大家都是 0」的結果**分不出高下**——比較實驗要挑在**有鑑別度**
%[text] 的操作點上做。sigma=1 才是這裡的關鍵點。
%[text] ## 對雜訊敏感的，對模糊也敏感——方向相反
%[text] 主教材測出 `Roberts` 對雜訊最敏感（固定門檻下增加 8.8 倍）。
%[text] 模糊測試裡，它的邊緣數**掉得也最快**：sigma=1 時只保留約 0.4%，
%[text] 而 Sobel／Prewitt 還有約 28%、Canny 有約 89%。
%[text] **這不是巧合，是同一件事的兩面**：
%[text] `Roberts` 用 2×2 的核，它的響應集中在**最高頻**。
%[text] - 雜訊 = 增加高頻 → Roberts 反應最劇烈（邊緣暴增）
%[text] - 模糊 = 移除高頻 → Roberts 也反應最劇烈（邊緣消失） \
%[text] 而 `Canny` 與 `log` 都先做高斯平滑，它們看的是**較低的頻帶**，
%[text] 所以對兩者都比較遲鈍。
%[text] **實務意義**：如果你的影像**又有雜訊又有點失焦**（工業現場很常見），
%[text] 小核算子會兩頭不討好。用 Canny，並把它的高斯 sigma 調到與你的
%[text] 失焦程度相稱。
%%
%[text] # 解答 2：Canny 雙門檻的作用
rng(0);
Inoisy = imnoise(I, "gaussian", 0, 0.003);
highT = 0.20;
%[text] **先踩一個 API 的坑**：想用 `edge(I,"Canny",[t t])` 模擬「單門檻」
%[text] 是行不通的——MATLAB 要求 `0 < low < high < 1` **嚴格成立**，
%[text] 高低相同會直接報錯：
try
    edge(Inoisy, "Canny", [highT highT]);
catch ME
    fprintf("edge(...,[t t]) 的錯誤：%s\n\n", ME.message);
end
%[text] 所以改用**掃描低／高門檻的比例**來看遲滯的作用。
%[text] 比例接近 1 就接近單門檻，比例越小遲滯的空間越大。
ratios = [0.99 0.90 0.70 0.40];
hysteresisResults = cell(size(ratios));

% 連續性指標：同樣的邊緣長度下，連通元件越多代表越破碎
fragmentation = @(bw) max(bwlabel(bw), [], "all") / max(nnz(bw), 1) * 1000;

fprintf("%-14s %12s %14s %18s\n", "low/high", "邊緣像素", "連通元件數", "每千像素斷片數");
for k = 1:numel(ratios)
    hysteresisResults{k} = edge(Inoisy, "Canny", [ratios(k)*highT highT]);
    fprintf("%-14.2f %12d %14d %18.1f\n", ratios(k), ...
        nnz(hysteresisResults{k}), ...
        max(bwlabel(hysteresisResults{k}), [], "all"), ...
        fragmentation(hysteresisResults{k}));
end

figure
montage(hysteresisResults, Size=[2 2])
title("low/high = 0.99（近乎單門檻）｜ 0.90 ｜ 0.70 ｜ 0.40")
%[text] **關鍵觀察：邊緣像素數上升，斷片密度卻下降**（51.2 → 24.0）。
%[text] 如果低門檻只是單純放寬、把更多雜訊點放進來，那麼邊緣數和斷片數
%[text] 應該**同時**上升——因為雜訊點是孤立的，每一個都會多出一個連通元件。
%[text] 實際上斷片密度**減半**了，代表那些新增的像素是**把原本斷開的邊緣接起來**。
%[text] 這正是遲滯門檻的設計目的：弱邊緣只有在**與強邊緣相連**時才保留，
%[text] 所以它只會補洞，不會憑空製造孤立的雜訊點。
%[text] **MATLAB 預設的 0.4 比例**（`edge(I,"Canny",t)` 只給一個數字時）
%[text] 正好落在這個掃描的最佳端。
%%
%[text] # 解答 3：自動推算半徑範圍
%[text] 完整實作在 `code/ch10_autoCircles.m`。
% 在產生合成影像之前重設亂數種子。前面的段落已經消耗過亂數，
% 不重設的話雜訊的實現會不同，偵測結果也會跟著變——這正是第 02 章
% 「含隨機成分的實驗要固定種子」的實例。
rng(0);

[gx, gy] = meshgrid(1:500, 1:400);
circleSpecs = [80 90 15; 200 100 28; 350 110 45; 120 280 22; 280 300 35; 420 290 12];
synthetic = zeros(400, 500, "uint8") + 30;
for k = 1:size(circleSpecs,1)
    synthetic((gx-circleSpecs(k,1)).^2 + (gy-circleSpecs(k,2)).^2 < circleSpecs(k,3)^2) = 200;
end
synthetic = imnoise(synthetic, "gaussian", 0, 0.002);

[autoCenters, autoRadii, autoInfo] = ch10_autoCircles(synthetic);

fprintf("自動偵測 %d 個圓（正解 6）\n", numel(autoRadii));
fprintf("判定為多峰分布：%d\n", autoInfo.Multimodal);
fprintf("自動選出的搜尋區間：\n");
for k = 1:size(autoInfo.RadiusBands,1)
    fprintf("  [%d %d] → 找到 %d 個\n", autoInfo.RadiusBands(k,1), ...
        autoInfo.RadiusBands(k,2), autoInfo.DetectionsPerBand(k));
end
fprintf("偵測半徑 %s\n", mat2str(round(sort(autoRadii)', 1)));
fprintf("真實半徑 %s\n", mat2str(sort(circleSpecs(:,3))'));

figure
imshow(synthetic), hold on
viscircles(autoCenters, autoRadii, Color="g");
hold off
title(sprintf("ch10\\_autoCircles：%d 個圓，無需人工給半徑", numel(autoRadii)))
%%
%[text] ## 它和 imfindcirclesYOLO 相比還缺什麼
comparison = {"ch10_autoCircles（自動霍夫）", numel(autoRadii)};
if hasYOLOCircles
    [~, yoloR] = imfindcirclesYOLO(synthetic);
    comparison(end+1,:) = {"imfindcirclesYOLO", numel(yoloR)};
end
comparison(end+1,:) = {"imfindcircles [10 50]（人工）", ...
    numel(secondOutput(@() imfindcircles(synthetic, [10 50], Sensitivity=0.92)))};

fprintf("\n%-32s %s\n", "方法", "找到（正解 6）");
for k = 1:size(comparison,1)
    fprintf("%-32s %d\n", comparison{k,:});
end
%[text] **在這個案例上三者打平**——自動霍夫的半徑估計甚至和 YOLO 一樣準
%[text] （誤差都在 1 像素內）。那 YOLO 的優勢到底在哪？
%[text] **關鍵在前置條件。** `ch10_autoCircles` 的第一步是**門檻分割**，
%[text] 它必須先能把圓從背景分出來，才有辦法估尺寸。這代表它繼承了
%[text] 門檻分割的所有弱點（第 08 章講過的那些）：
%[text:table]
%[text] | 情況 | `ch10_autoCircles` | `imfindcirclesYOLO` |
%[text] | --- | --- | --- |
%[text] | 對比清楚、背景單純 | **可用，且快 5–12 倍** | 可用 |
%[text] | 照明不均 | 門檻失效 → 尺寸估錯 → 整條路斷掉 | 不受影響 |
%[text] | 圓彼此重疊 | 分不開 → 尺寸估成一大塊 | 通常仍可分辨 |
%[text] | 背景雜亂 | 分割出一堆雜訊 | 不受影響 |
%[text] | 低對比 | 門檻抓不到 | 視訓練資料而定 |
%[text:table]
%[text] **YOLO 的價值不是「更準」，而是「不需要前置分割」。**
%[text] 它直接從像素辨認圓形，跳過了整個門檻環節。
%[text] 這在**影像條件不可控**的場合是決定性的差異。
%%
%[text] # 解答 4：圓偵測的對決
testConditions = { ...
    "基準（清楚）",     synthetic; ...
    "低對比",          uint8(double(synthetic)*0.25 + 90); ...
    "高雜訊",          imnoise(synthetic, "gaussian", 0, 0.02); ...
    "部分遮擋",        occludeCircles(synthetic)};

fprintf("%-16s %14s %14s %12s\n", "條件", "自動霍夫", "YOLO", "正解");
for k = 1:size(testConditions,1)
    X = testConditions{k,2};

    warnState = warning("off", "all");
    try
        [~, rAuto] = ch10_autoCircles(X);
        nAuto = numel(rAuto);
    catch
        nAuto = NaN;
    end
    warning(warnState);

    if hasYOLOCircles
        [~, rY] = imfindcirclesYOLO(X);
        nY = numel(rY);
    else
        nY = NaN;
    end

    fprintf("%-16s %14d %14d %12d\n", testConditions{k,1}, nAuto, nY, 6);
end

figure
montage(testConditions(:,2)', Size=[2 2])
title("基準 ｜ 低對比 ｜ 高雜訊 ｜ 部分遮擋")
%[text] ## 決策表
%[text:table]
%[text] | 情況 | 建議 | 理由 |
%[text] | --- | --- | --- |
%[text] | 尺寸固定、影像條件受控 | **`imfindcircles`**（手動給範圍） | 最快，且完全可解釋 |
%[text] | 尺寸未知但影像條件受控 | **`ch10_autoCircles`** | 免調參數，仍比 YOLO 快得多 |
%[text] | **影像條件不可控** | **`imfindcirclesYOLO`** | 不依賴門檻分割 |
%[text] | 部分遮擋的圓 | 霍夫類方法 | 投票法只需要部分邊緣點就能形成峰值 |
%[text] | 沒有 GPU／不能裝支援包 | 霍夫類方法 | YOLO 在 CPU 上太慢 |
%[text:table]
%[text] **部分遮擋是霍夫的主場**。它是投票法——圓的一部分邊緣點就足以
%[text] 在累加器裡形成峰值。深度學習偵測器則要看訓練資料裡有沒有類似的樣本。
%[text] ## 這個測試的一個缺陷，值得說清楚
%[text] 注意「低對比」那一列：**自動霍夫 6 個、YOLO 5 個**——YOLO 反而輸了。
%[text] 這和決策表寫的「條件不可控就用 YOLO」看起來矛盾。
%[text] **問題出在測試本身。** 我造低對比影像的方式是
%[text] `uint8(double(I)*0.25 + 90)`——這是一個**全域的線性變換**，
%[text] 背景仍然完全均勻。`imbinarize` 的 Otsu 門檻會自動適應這種變化，
%[text] **前置分割根本沒有被打敗**，自動霍夫當然照常運作。
%[text] 真正會打敗門檻分割的是**背景不均勻**：照明梯度、陰影、雜亂的背景紋理。
%[text] 要公平測試，低對比案例應該再疊上一個光場梯度。
%[text] **這一節的教訓**：**設計對照實驗時，要確認你的「困難案例」
%[text] 真的困難到會打敗你想打敗的那個機制。**
%[text] 我原本以為「低對比」會讓門檻失效，但實際上它只是換了一個數值範圍，
%[text] 而 Otsu 是自適應的。這和第 2.2 節「自動門檻掩蓋差異」是同一類疏忽——
%[text] **沒有控制住那個會自我調整的環節**。
%%
%[text] # 解答 5：把門檻的來歷寫下來
%[text] 主教材示範了「換掉 `bwmorph` 為 `bwskel` 讓寫死的門檻 58 失效」。
%[text] 防止這件事的機制是：**讓門檻帶著它的產生條件一起流動**。
%[text] 完整實作在 `code/ch10_classifyWorm.m`。核心概念很簡單——
%[text] 把設定打包成一個「指紋」，用門檻時比對指紋是否一致。
bw1 = logical(imread("wormsBW1.png"));
bw2 = logical(imread("wormsBW2.png"));

% 用新版設定產生門檻，並記下它的來歷
[len1, ~, fp1] = ch10_wormLengthWithFingerprint(bw1, SkeletonMethod="bwskel");
[len2, ~, fp2] = ch10_wormLengthWithFingerprint(bw2, SkeletonMethod="bwskel");

calibration = struct( ...
    "Threshold",   mean([len1 len2]), ...
    "Fingerprint", fp1, ...
    "Source",      "由 wormsBW1／wormsBW2 於 " + string(datetime("today")) + " 校正");

fprintf("校正出的門檻：%.1f\n", calibration.Threshold);
fprintf("指紋：%s\n\n", calibration.Fingerprint);

fprintf("--- 用相同設定分類（應該正常）---\n");
ch10_classifyWorm(len1, calibration, fp1);
ch10_classifyWorm(len2, calibration, fp2);

fprintf("\n--- 改用舊版骨架化再分類（應該被攔截）---\n");
[lenOld, ~, fpOld] = ch10_wormLengthWithFingerprint(bw2, SkeletonMethod="bwmorph");
ch10_classifyWorm(lenOld, calibration, fpOld);
%[text] **警告成功攔截了不一致的使用。**
%[text] 這個機制的成本極低——多存一個字串而已——
%[text] 但它能防止一整類「悄悄出錯」的問題。
%[text] **原則**：任何寫死的常數，都應該和「產生它的條件」綁在一起流動。
%[text] 第 19 章的模型評估門檻、第 22 章的瑕疵判定門檻，都適用同一個原則。
%[text] 在那些章節，指紋會包含**模型版本、訓練資料版本、前處理設定**——
%[text] 概念完全相同，只是欄位更多。
%%
%[text] # 加分題：次像素邊緣定位
coins = im2double(imread("coins.png"));
profileRow = 130;
profile = coins(profileRow, :);
gradient1D = gradient(profile);

figure
tiledlayout(3,1)
nexttile; imshow(coins); hold on
yline(profileRow, "r-", LineWidth=1.5); hold off
title("取樣位置")
nexttile; plot(profile, LineWidth=1.2); grid on
ylabel("亮度"); title("剖面")
nexttile; plot(abs(gradient1D), LineWidth=1.2); grid on
xlabel("行"); ylabel("|梯度|"); title("梯度（峰值＝邊界）")

% 找出梯度的兩個主要峰值（硬幣的左右邊界）
[peakVals, peakIdx] = findpeaks(abs(gradient1D), MinPeakProminence=0.02);
[~, strongest] = maxk(peakVals, 2);
edgeIdx = sort(peakIdx(strongest));

fprintf("像素級邊界位置：%d 與 %d\n", edgeIdx(1), edgeIdx(2));
fprintf("像素級直徑：%d 像素\n\n", diff(edgeIdx));

% 次像素：用三點拋物線頂點公式
subpixel = zeros(1,2);
g = abs(gradient1D);
for k = 1:2
    i = edgeIdx(k);
    ym = g(i-1);  y0 = g(i);  yp = g(i+1);
    delta = 0.5 * (ym - yp) / (ym - 2*y0 + yp);
    subpixel(k) = i + delta;
    fprintf("邊界 %d：像素 %d，次像素修正 %+.3f → %.3f\n", k, i, delta, subpixel(k));
end

fprintf("\n次像素直徑：%.3f 像素\n", diff(subpixel));
fprintf("與像素級的差異：%.3f 像素（%.2f%%）\n", ...
    abs(diff(subpixel) - diff(edgeIdx)), ...
    100*abs(diff(subpixel) - diff(edgeIdx))/diff(edgeIdx));
%[text] ## 一個反直覺的結果：直徑幾乎沒變
%[text] 兩個邊界各自被修正了約 +0.07 像素，但**直徑只差了 0.003 像素**。
%[text] 為什麼？因為兩邊的修正量**方向相同、大小相近**，相減時抵銷掉了。
%[text] 這揭示了一件重要的事：
%[text:table]
%[text] | 你要量什麼 | 次像素有沒有幫助 |
%[text] | --- | --- |
%[text] | **位置**（物件在哪裡、對位、配準） | **很有幫助**，修正量直接貢獻 |
%[text] | **寬度／直徑**（兩個邊界相減） | **要看兩邊的修正是否對稱** |
%[text] | 兩邊對稱（本例） | 幫助有限，修正互相抵銷 |
%[text] | 兩邊不對稱（單邊模糊、單邊反光） | **很有幫助**，抵銷不掉 |
%[text:table]
%[text] **所以「次像素一定更準」是個過度簡化的說法。**
%[text] 它提升的是**邊界定位**的精度；那個精度會不會傳遞到你的最終量測，
%[text] 取決於你的量測是怎麼組合這些邊界的。
%[text] 什麼時候真的有感：
%[text] - 量**位置**（定位、對位、配準）——修正量全額貢獻
%[text] - 兩側成像條件**不對稱**時量寬度——例如單邊有反光或陰影
%[text] - 物件**很小**時——量一個 10 像素寬的特徵，0.1 像素就是 1% \
%[text] 換算成實際尺寸更有感：若相機的空間解析度是 0.1 mm/像素，
%[text] 0.1 像素就是 **10 微米**。這在精密量測上不是小數目。
%[text] **次像素插值是免費的精度提升**——不需要更好的相機，只需要多算幾行——
%[text] **但要知道它提升的是什麼**。
%[text] **但它有前提**：
%[text] 1. 邊界必須是**平滑過渡**的（有抗鋸齒），硬邊界沒有次像素資訊可插
%[text] 2. 雜訊會直接污染插值結果，**量測前務必先去雜訊**（第 04 章）
%[text] 3. 三點拋物線假設梯度峰值附近是對稱的，強烈不對稱時要用更多點擬合 \
%[text] 第 11 章會把這個技巧放進完整的量測流程，並討論**空間校正**——
%[text] 怎麼把「像素」變成「公釐」。

function out = secondOutput(fcn)
%SECONDOUTPUT 取函式的第二個輸出（用來在運算式中取 imfindcircles 的半徑）。
[~, out] = fcn();
end

function J = occludeCircles(I)
%OCCLUDECIRCLES 用幾個矩形遮住部分圓，模擬遮擋。
J = I;
J(80:130, 180:230)  = 30;
J(260:320, 100:150) = 30;
end

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline","rightPanelPercent":40}
%---
