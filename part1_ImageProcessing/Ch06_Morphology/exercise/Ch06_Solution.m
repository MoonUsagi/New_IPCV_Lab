%[text] # 第 06 章　練習解答
assert(exist("ch06_cleanMask","file") == 2, ...
    "請先切換到課程根目錄並執行 ipcvSetup。");
rng(0);
%%
%[text] # 解答 1：用形態學移除掃描線
BW = imread("blobs.png");
withLines = BW;
withLines(20:30:end, :) = true;

%[text] 關鍵是用**水平線**結構元素做開運算——只有「水平方向夠長」的結構
%[text] 才能讓線 SE 完全放進去而存活下來。
%[text] 但長度要選對。掃描一遍看看：
lengths = [151 201 251 301];
fprintf("%-10s %10s %12s %14s\n", "SE 長度", "抓到像素", "誤傷物件", "物件保留率");
for L = lengths
    detected = imopen(withLines, strel("line", L, 0));
    cleaned  = withLines & ~detected;
    fprintf("%-10d %10d %12d %13.1f%%" + "\n", L, nnz(detected), nnz(detected & BW), ...
        100*nnz(cleaned & BW)/nnz(BW));
end
%[text] **L=251 是分水嶺**。低於它，影像中較寬的物件內部也有夠長的水平段，
%[text] 會被誤判成線而挖掉——151 時物件只剩 58%，破壞嚴重。
%[text] 251 以上則穩定在「抓到 2961 個線像素、只誤傷 380 個物件像素、
%[text] 保留 97.3% 物件面積」。
bestLength = 251;
detected = imopen(withLines, strel("line", bestLength, 0));
cleaned  = withLines & ~detected;

figure
montage({withLines, detected, cleaned, BW}, Size=[2 2])
title("有干擾 ｜ 偵測到的線 ｜ 移除後 ｜ 原始正解")

fprintf("\n殘留的線：%d 列\n", nnz(all(cleaned & ~BW, 2)));
fprintf("與原始影像的差異：%d 像素（%.2f%%）\n", ...
    nnz(xor(cleaned, BW)), 100*nnz(xor(cleaned, BW))/numel(BW));
%[text] ## 為什麼選 251
%[text] 影像寬 329 像素，掃描線橫貫全寬。物件（blobs）的最大水平寬度
%[text] 大約 200 像素出頭。SE 長度只要**介於兩者之間**就能分開它們：
maxObjectWidth = max(sum(BW, 2));
fprintf("影像寬度         %d\n", size(BW,2));
fprintf("單列最大物件寬度 %d\n", maxObjectWidth);
fprintf("安全區間         %d – %d\n", maxObjectWidth + 1, size(BW,2));
%[text] **這就是形態學參數的迷人之處**：它有明確的幾何意義，
%[text] 可以從影像的實際尺寸直接推算，不必試誤。
%%
%[text] # 解答 2：分開黏在一起的物件
[xx, yy] = meshgrid(1:200, 1:200);
twoCircles = ((xx-80).^2 + (yy-100).^2 < 45^2) | ((xx-125).^2 + (yy-100).^2 < 45^2);

fprintf("直接計數：%d 個\n\n", max(bwlabel(twoCircles), [], "all"));
%[text] ## 方法一：侵蝕找標記 + 形態學重建
%[text] 侵蝕會先讓細的連接處斷開，粗的中心區域還在。
%[text] 用斷開後的兩塊當標記，重建回完整的圓。
marker = imerode(twoCircles, strel("disk", 20));
fprintf("侵蝕 r=20 後的標記數：%d\n", max(bwlabel(marker), [], "all"));
%[text] 只有 1 個——兩個圓重疊太深，侵蝕 20 還不夠。加大：
for r = [20 25 30 35]
    m = imerode(twoCircles, strel("disk", r));
    fprintf("  侵蝕 r=%d -> %d 個標記\n", r, max(bwlabel(m), [], "all"));
end
%%
%[text] ## 方法二：距離轉換 + 分水嶺（比較穩健）
%[text] 距離轉換給出「每個前景像素離背景多遠」。圓心的距離最大，
%[text] 兩圓交界處距離較小——這正好形成一個「山谷」，分水嶺可以沿著它切開。
D = -bwdist(~twoCircles);        % 取負號，讓圓心變成「谷底」
D(~twoCircles) = Inf;            % 背景不參與

Lraw = watershed(D);
Lraw(~twoCircles) = 0;
fprintf("\n直接分水嶺：%d 個（可能過度分割）\n", max(Lraw(:)));

Dsuppressed = imhmin(D, 2);      % 抑制深度小於 2 的淺谷，避免過度分割
L = watershed(Dsuppressed);
L(~twoCircles) = 0;
fprintf("先用 imhmin 抑制淺谷：%d 個\n", max(L(:)));

figure
tiledlayout(2,2)
nexttile; imshow(twoCircles);        title("兩個重疊的圓")
nexttile; imshow(mat2gray(-D));      title("距離轉換（亮 = 離背景遠）")
nexttile; imshow(label2rgb(L));      title(sprintf("分水嶺分割：%d 個", max(L(:))))
nexttile
stats = regionprops("table", L, "Area", "Centroid", "Circularity");
imshow(twoCircles); hold on
plot(stats.Centroid(:,1), stats.Centroid(:,2), "r+", MarkerSize=15, LineWidth=2)
hold off; title("偵測到的圓心")

disp(stats)
%[text] **驗證**：兩個區域的面積應該接近單一圓的面積 $\pi\times45^2\approx6362$，
%[text] 圓形度應該接近 1（雖然因為被切了一刀，會略低）。
fprintf("\n理論單圓面積 %.0f\n", pi*45^2);
fprintf("實際兩區面積 %s\n", mat2str(round(stats.Area')));
%[text] **`imhmin` 是分水嶺的標準搭配**。沒有它，距離轉換上的微小起伏
%[text] 都會被當成獨立的「集水區」，造成嚴重的過度分割。
%[text] 這個組合（距離轉換 → imhmin → watershed）是第 08 章分割的核心工具。
%%
%[text] # 解答 3：形態學清理函式
%[text] 完整實作在 `code/ch06_cleanMask.m`。它的價值在於那張 **log table**——
%[text] 當結果不對時，可以立刻看出是哪一步殺掉了物件。
rice = imread("rice.png");
bw = imbinarize(imtophat(rice, strel("disk", 15)));

[clean, log] = ch06_cleanMask(bw, MinArea=30, ClearBorder=true);
disp(log)
%[text] 看這張表就能發現問題：**閉運算把物件從 98 個變成 81 個**。
%[text] 為什麼？米粒彼此靠得很近，`imclose` 半徑 3 把相鄰的米粒連起來了。
%[text] 這正是 log table 的用途——如果只看最後結果（56 個），
%[text] 你不會知道是哪一步出的問題。
%[text] 針對米粒這種「密集小物件」，應該**關掉閉運算**：
[clean2, log2] = ch06_cleanMask(bw, CloseRadius=0, MinArea=30, ClearBorder=true);
disp(log2)

figure
montage({bw, clean, clean2}, Size=[1 3])
title(sprintf("原始遮罩 ｜ 預設清理（%d 個）｜ 關閉閉運算（%d 個）", ...
    max(bwlabel(clean),[],"all"), max(bwlabel(clean2),[],"all")));

fprintf("\n預設設定     最終 %d 個\n", max(bwlabel(clean), [], "all"));
fprintf("關掉閉運算   最終 %d 個  <- 正確得多\n", max(bwlabel(clean2), [], "all"));
%[text] **通用教訓**：不要盲目套用「標準清理流程」。
%[text] 每一個形態學步驟都可能傷到你的物件，要有辦法看出是哪一步。
%%
%[text] # 解答 4：粒徑分析認出兩種尺寸
rng(0);
[gx, gy] = meshgrid(1:400, 1:400);
canvas = false(400, 400);
for k = 1:12
    cx = randi([20 380]);  cy = randi([20 380]);
    canvas = canvas | ((gx - cx).^2 + (gy - cy).^2 < 8^2);
end
for k = 1:6
    cx = randi([30 370]);  cy = randi([30 370]);
    canvas = canvas | ((gx - cx).^2 + (gy - cy).^2 < 20^2);
end

radiiScan = 1:1:30;
remaining = zeros(size(radiiScan));
for k = 1:numel(radiiScan)
    remaining(k) = nnz(imopen(canvas, strel("disk", radiiScan(k))));
end

granulometry = -diff(remaining);
scanCenters  = radiiScan(2:end);

[pks, locs] = findpeaks(granulometry, scanCenters, MinPeakProminence=max(granulometry)*0.1);

figure
tiledlayout(1,2)
nexttile
imshow(canvas); title("大小兩種圓")
nexttile
bar(scanCenters, granulometry); hold on
plot(locs, pks, "rv", MarkerSize=10, MarkerFaceColor="r"); hold off
xlabel("SE 半徑"); ylabel("消失的面積"); title("粒徑分布"); grid on

fprintf("找到 %d 個峰值，位置在 SE 半徑 = %s\n", numel(locs), mat2str(locs));
fprintf("實際的圓半徑是 8 與 20\n");
%[text] 峰值位置對應圓的半徑——因為 disk 半徑超過圓半徑時，
%[text] 該尺寸的圓就會在開運算中完全消失。
%[text] **為什麼不需要先分割**：這個方法量的是「整張影像的形狀尺度特性」，
%[text] 而不是「每個物件的尺寸」。即使圓彼此重疊、連成一片，
%[text] 開運算仍然會在對應的 SE 半徑把它們消掉。
%[text] 這在**顆粒、粉末、細胞**等「數不清但要知道尺寸分布」的場合極為實用——
%[text] 傳統做法要先分割出每個顆粒（很難），粒徑分析完全跳過這一步。
%%
%[text] # 解答 5：形態學梯度 vs Canny
I = im2double(imread("cameraman.tif"));
rng(0);
J = imnoise(I, "gaussian", 0, 0.005);

se1 = strel("disk", 1);
morphGradient = @(X) imbinarize(imsubtract(imdilate(X, se1), imerode(X, se1)));
dice = @(a,b) 2*nnz(a & b) / (nnz(a) + nnz(b));

reference = edge(I, "Canny");     % 以乾淨影像的 Canny 當「正解」

results = { ...
    "Canny（乾淨）",    edge(I, "Canny"); ...
    "Canny（雜訊）",    edge(J, "Canny"); ...
    "形態梯度（乾淨）", morphGradient(I); ...
    "形態梯度（雜訊）", morphGradient(J)};

fprintf("%-18s %10s\n", "方法", "Dice");
for k = 1:size(results,1)
    fprintf("%-18s %10.3f\n", results{k,1}, dice(results{k,2}, reference));
end

figure
montage(results(:,2)', Size=[2 2])
title("Canny 乾淨 ｜ Canny 雜訊 ｜ 形態梯度 乾淨 ｜ 形態梯度 雜訊")
%[text] ## 解讀：要看**相對變化**，不是絕對值
%[text:table]
%[text] | 方法 | 乾淨 | 雜訊 | 變化 |
%[text] | --- | --- | --- | --- |
%[text] | Canny | 1.000 | 0.540 | **−46%** |
%[text] | 形態梯度 | 0.416 | 0.411 | **−1%** |
%[text:table]
%[text] **形態梯度穩健得多**——加了雜訊幾乎不受影響，而 Canny 掉了將近一半。
%[text] **為什麼**：Canny 建立在**微分**上。微分會放大高頻，而雜訊正是高頻——
%[text] 單一個異常像素就會製造出一個假邊緣。
%[text] 形態梯度用的是鄰域的**極值差**（最大減最小）。它對雜訊不是免疫，
%[text] 但一個異常像素只會影響它所在的那個鄰域，不會像微分那樣被放大。
%[text] **但要注意這個比較對形態梯度不公平**：絕對 Dice 值只有 0.416，
%[text] 是因為形態梯度產生的是**粗的邊緣帶**，Canny 產生的是**單像素細線**。
%[text] 兩者在幾何上本來就對不太起來，不是形態梯度「比較差」。
%[text] **正確的結論**：
%[text] - 要**細緻、單像素**的邊緣 → Canny（但要先去雜訊）
%[text] - 要**穩健、不怕雜訊**的邊界帶 → 形態梯度
%[text] - 比較兩種輸出形式不同的方法時，**單一指標可能誤導**——
%[text] 要看的是它在你關心的條件下如何變化 \
%[text] 這呼應第 03 章的教訓：**選錯指標就會得到錯誤的結論。**
%%
%[text] # 加分題：用形態學做文字行與字元切割
page = imread("printedtext.png");

%[text] ## 先踩一次坑：直接二值化會失敗
%[text] 這張影像的照明**極度不均**（它本來就是 MATLAB 用來示範這個問題的範例）。
%[text] 直接二值化，不論全域或自適應，都得不到可用的結果：
naiveGlobal   = imbinarize(page);
naiveAdaptive = imbinarize(page, "adaptive", ForegroundPolarity="dark", Sensitivity=0.4);

fprintf("直接全域 Otsu   前景 %.1f%%（文字應該只佔幾 %%）\n", 100*mean(naiveGlobal,"all"));
fprintf("直接自適應門檻  前景 %.1f%%" + "\n", 100*mean(naiveAdaptive,"all"));
fprintf("空白列數        %d / %d（正常的文字頁應該有很多空白列）\n\n", ...
    nnz(sum(bwareaopen(naiveGlobal,20), 2) == 0), size(page,1));

figure
montage({page, naiveGlobal}, Size=[1 2])
title("原圖（照明極不均）｜ 直接二值化的結果（不可用）")
%[text] 一行空白列都沒有——代表整頁糊成一團，根本切不出文字行。
%%
%[text] ## 正確做法：先用 top-hat 校正照明
%[text] 文字是**暗的**，所以先取補色讓文字變亮，再用 top-hat 把不均勻的背景移除。
%[text] 這正是本章第 5 節學到的技巧。
inverted = imcomplement(page);                        % 文字變亮
corrected = imtophat(inverted, strel("disk", 20));    % 移除不均勻背景

textBW = bwareaopen(imbinarize(corrected), 20);

fprintf("top-hat 校正後  前景 %.1f%%" + "\n", 100*mean(textBW,"all"));
fprintf("空白列數        %d / %d  <- 行結構出現了\n", ...
    nnz(sum(textBW,2) == 0), size(page,1));

figure
montage({page, corrected, textBW}, Size=[1 3])
title("原圖 ｜ top-hat 校正後 ｜ 二值化")

% 步驟 1：用長的水平 SE 做閉運算，把同一行的字連成一條
lineMask = bwareaopen(imclose(textBW, strel("line", 60, 0)), 500);

numLines = max(bwlabel(lineMask), [], "all");
fprintf("\n偵測到 %d 行文字\n\n", numLines);

figure
montage({textBW, lineMask}, Size=[1 2])
title("二值化後的文字 ｜ 水平閉運算後的文字行")

% 步驟 2：在每一行內，回到原始遮罩切出個別字元
lineLabels = bwlabel(lineMask);
charCounts = zeros(numLines, 1);

for k = 1:numLines
    thisLine = textBW & (lineLabels == k);
    charCounts(k) = max(bwlabel(thisLine), [], "all");
end

disp(table((1:numLines)', charCounts, VariableNames=["行號" "字元數"]))
fprintf("總計 %d 個字元\n", sum(charCounts));
%[text] **為什麼要分兩步**：直接對整張影像做連通元件分析，會得到一堆
%[text] 沒有順序的字元——你不知道哪個字屬於哪一行、該怎麼排。
%[text] 先用**水平方向的 SE** 把行結構找出來，就建立了「由上到下、
%[text] 由左到右」的閱讀順序。這是 OCR 前處理的標準做法。
%[text] **SE 長度的意義**：它必須**大於字元間距、小於行距**。
%[text] 太短連不成行，太長會把上下兩行連在一起。
%[text] ## 這題真正的重點
%[text] 字元切割本身不難，難的是**發現要先做照明校正**。
%[text] 如果你一開始就跳到「用水平 SE 找文字行」，會得到 1 行——
%[text] 然後花很久去調 SE 長度，卻怎麼調都不對，因為問題根本不在那裡。
%[text] **先檢查你的二值化結果合不合理**（文字頁應該有大量空白列），
%[text] 再往下做。這個習慣能省下大量時間。
%[text] 第 15 章做 OCR 時，會看到現代的深度學習文字偵測器如何取代這一步——
%[text] 但理解這個傳統流程，能幫你判斷偵測器的輸出是否合理。

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline","rightPanelPercent":40}
%---
