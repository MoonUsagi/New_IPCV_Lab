%[text] # 第 15 章　練習解答
%[text] 符碼、文字偵測與 OCR
assert(exist("ch15_cer","file") == 2, ...
    "請先切換到課程根目錄並執行 ipcvSetup。");
hasCRAFT = exist("detectTextCRAFT", "file") > 0;
rng(0);
%%
%[text] # 解答 1：條碼的二維可讀區域
%[text] 掃「模糊 × 縮放」的組合，畫出可讀區域的邊界。
QR  = imread("barcodeQR.jpg");
EAN = imread("barcode1D.jpg");

sigmas = 0:0.5:5;
scales = [1 0.8 0.6 0.5 0.4 0.3 0.25 0.2];

okQR  = false(numel(scales), numel(sigmas));
okEAN = false(numel(scales), numel(sigmas));

for si = 1:numel(scales)
    for bi = 1:numel(sigmas)
        A = imresize(QR, scales(si));
        B = imresize(EAN, scales(si));
        if sigmas(bi) > 0
            A = imgaussfilt(A, sigmas(bi));
            B = imgaussfilt(B, sigmas(bi));
        end
        okQR(si,bi)  = decodes(A);
        okEAN(si,bi) = decodes(B);
    end
end

fprintf("\nQR 可讀率 %.1f%%（%d / %d 組合）\n", ...
    100*mean(okQR(:)), nnz(okQR), numel(okQR));
fprintf("1D 可讀率 %.1f%%（%d / %d 組合）\n", ...
    100*mean(okEAN(:)), nnz(okEAN), numel(okEAN));

figure
tiledlayout(1,2, TileSpacing="compact")
nexttile
imagesc(sigmas, scales, double(okQR)); colormap(gca, [0.85 0.3 0.3; 0.3 0.7 0.4])
set(gca, YDir="normal"); xlabel("模糊 \sigma"); ylabel("縮放倍率")
title("QR 可讀區域（綠 = 可讀）"); colorbar(Ticks=[0 1], TickLabels=["不可讀" "可讀"])
nexttile
imagesc(sigmas, scales, double(okEAN)); colormap(gca, [0.85 0.3 0.3; 0.3 0.7 0.4])
set(gca, YDir="normal"); xlabel("模糊 \sigma"); ylabel("縮放倍率")
title("EAN-13 可讀區域"); colorbar(Ticks=[0 1], TickLabels=["不可讀" "可讀"])
%%
%[text] ## 邊界曲線：相加還是相乘？
%[text] 對每個縮放倍率，找出**最大可容忍的模糊量**。
maxSigmaQR  = nan(size(scales));
maxSigmaEAN = nan(size(scales));
for si = 1:numel(scales)
    idx = find(okQR(si,:), 1, "last");
    if ~isempty(idx), maxSigmaQR(si) = sigmas(idx); end
    idx = find(okEAN(si,:), 1, "last");
    if ~isempty(idx), maxSigmaEAN(si) = sigmas(idx); end
end

fprintf("\n%-10s %16s %16s\n", "縮放", "QR 容忍 sigma", "1D 容忍 sigma");
for si = 1:numel(scales)
    fprintf("%-10.2f %16.1f %16.1f\n", scales(si), maxSigmaQR(si), maxSigmaEAN(si));
end

figure
plot(scales, maxSigmaQR, "o-", LineWidth=1.8, DisplayName="QR")
hold on
plot(scales, maxSigmaEAN, "s-", LineWidth=1.8, DisplayName="EAN-13")
hold off
xlabel("縮放倍率"); ylabel("最大可容忍的模糊 \sigma")
title("可讀區域的邊界曲線"); legend(Location="northwest"); grid on

% 相加(線性) vs 相乘(比例) 的檢定：看邊界是否與縮放成正比
ok1 = isfinite(maxSigmaQR) & scales > 0;
if nnz(ok1) >= 3
    ratio = maxSigmaQR(ok1) ./ scales(ok1);
    fprintf("\nQR：容忍sigma / 縮放 的比值 = %s\n", ...
        mat2str(round(ratio,2)));
    fprintf("     變異係數 %.3f（接近 0 代表成正比 -> 相乘關係）\n", ...
        std(ratio)/mean(ratio));
end
%[text] **第 4 小題：兩種劣化接近相乘，但不完全。**
%[text] 「容忍的模糊量 ÷ 縮放倍率」的比值是
%[text] `4.5, 5, 5, 4, 3.75, 3.33, 2, 2.5`，變異係數 **0.294**。
%[text] 若完全成正比，比值應該是常數（變異係數接近 0）。
%[text] 0.294 代表**大致成正比，但小尺度時比值明顯下降**
%[text] （從 5 掉到 2）。
%[text] 相乘的部分符合物理：條碼能不能解碼，取決於**最細的條佔幾個像素**。
%[text] 縮小一半，條就只剩一半的像素，能容忍的模糊自然也只剩一半。
%[text] 而小尺度時比值下降，是因為多了一個**絕對下限**：
%[text] 條再怎麼樣也需要至少一兩個像素才存在，
%[text] 那個下限不隨比例縮放。
%[text] > **所以規格要寫兩條**：一條比例規格（最細條至少 N 個像素），
%[text] > 加一條絕對規格（影像至少 M 像素寬）。
%[text] 但**不要**分別寫「解析度至少 X」與「模糊不超過 Y」——
%[text] 那兩個獨立規格會過度嚴格（必須同時滿足），
%[text] 而真正的限制是它們的**組合**。
%%
%[text] # 解答 2：最小可讀字高（以像素計）
gt = "ABCDEFG 0123456789";
fontSizes = [8 10 12 14 16 20 24 32];
fontsToTry = ["Roboto-Regular" "Arial" "Courier New"];

fprintf("\n%-18s %10s %14s %10s\n", "字型", "FontSize", "實測字高(px)", "CER");
resAll = struct("font", {}, "heights", {}, "cers", {});

for f = fontsToTry
    heights = nan(size(fontSizes));
    cers    = nan(size(fontSizes));
    usable = true;
    for k = 1:numel(fontSizes)
        try
            A = makeTextWithFont(gt, fontSizes(k), f);
        catch
            usable = false; break
        end
        heights(k) = measureGlyphHeight(A);
        cers(k) = ch15_cer(ch15_cleanText(ocr(A).Text), gt);
    end
    if ~usable
        fprintf("%-18s （此字型不可用，略過）\n", f);
        continue
    end
    for k = 1:numel(fontSizes)
        fprintf("%-18s %10d %14.1f %10.4f\n", f, fontSizes(k), heights(k), cers(k));
    end
    resAll(end+1) = struct("font", f, "heights", heights, "cers", cers);
end
%%
%[text] ## 臨界像素高度
figure
hold on
markers = ["o" "s" "^"];
for k = 1:numel(resAll)
    plot(resAll(k).heights, resAll(k).cers, markers(min(k,3)) + "-", ...
        LineWidth=1.8, MarkerSize=8, DisplayName=resAll(k).font);
end
yline(0, "--", "CER = 0", LineWidth=1.2);
hold off
xlabel("實測字元像素高度"); ylabel("CER")
title("最小可讀字高"); legend(Location="northeast"); grid on

fprintf("\n%-18s %22s\n", "字型", "CER 開始 > 0 的字高");
for k = 1:numel(resAll)
    bad = find(resAll(k).cers > 0, 1, "last");
    if isempty(bad)
        fprintf("%-18s %22s\n", resAll(k).font, "測試範圍內全部正確");
    else
        fprintf("%-18s %22.1f px\n", resAll(k).font, resAll(k).heights(bad));
    end
end
%[text] **第 5 小題：臨界高度與字型有關。**
%[text] 不同字型在**同樣的 FontSize** 下畫出來的實際字高不同
%[text] （襯線字型、等寬字型的字身比例都不一樣），
%[text] 而且筆畫粗細也不同——細筆畫的字型需要更多像素才不會斷裂。
%[text] > **所以「字元至少要 20 像素高」這種規格必須註明字型與字重。**
%[text] > 這與第 11 章的「校正指紋」是同一個原則：
%[text] > **任何從實驗得到的常數，都要帶著它的實驗條件一起流動。**
%[text] 實務上建議寫成：
%[text] 「以 ___ 字型、___ 字重量測，字元 x-height 至少 ___ 像素」。
%%
%[text] # 解答 3：`CharacterSet` 對中文 OCR 的效果
zhTruth = "影像處理與電腦視覺";
charsets = struct( ...
    "name", {"不限制", "寬鬆(約60字)", "中等(20字)", "嚴格(僅目標9字)"}, ...
    "set",  {"", ...
             "影像處理與電腦視覺資料分析系統設計實作方法研究開發技術應用程式碼測試驗證結果報告文件說明書範例教學課程學習", ...
             "影像處理與電腦視覺資料分析系統設計實作方法", ...
             zhTruth});

fontSizesZh = [40 60 80 100];
cerGrid = nan(numel(charsets), numel(fontSizesZh));
usedFontZh = "";

for fi = 1:numel(fontSizesZh)
    [img, uf] = ch15_makeCJKImage(zhTruth, fontSizesZh(fi));
    if isempty(img), continue, end
    usedFontZh = uf;
    for ci = 1:numel(charsets)
        if strlength(charsets(ci).set) == 0
            t = ocr(img, Model="chinesetraditional");
        else
            t = ocr(img, Model="chinesetraditional", ...
                CharacterSet=charsets(ci).set);
        end
        cerGrid(ci, fi) = ch15_cer(ch15_cleanText(t.Text), zhTruth);
    end
end

if strlength(usedFontZh) == 0
    fprintf("\n找不到中文字型，跳過解答 3。\n");
else
    fprintf("\n字型 %s，ground truth [%s]（%d 字）\n\n", ...
        usedFontZh, zhTruth, strlength(zhTruth));
    fprintf("%-20s", "CharacterSet");
    fprintf("%12s", "FontSize " + string(fontSizesZh)); fprintf("\n");
    for ci = 1:numel(charsets)
        fprintf("%-20s", charsets(ci).name);
        fprintf("%12.4f", cerGrid(ci,:));
        fprintf("\n");
    end

    baseline = cerGrid(1,1);
    gainChar = baseline - min(cerGrid(:,1));
    gainSize = baseline - min(cerGrid(1,:));
    fprintf("\n從基準（不限制、40pt，CER %.4f）出發：\n", baseline);
    fprintf("  只加大字級的最大改善 = %.4f\n", gainSize);
    fprintf("  只限制字元集的最大改善 = %.4f\n", gainChar);
end
%%
%[text] ## 第 5 小題的陷阱：「嚴格」的 0 是真的嗎
%[text] 若「僅目標 9 字」的設定把 CER 降到 0，那可能只是因為
%[text] **OCR 沒有別的字可以選**——它被迫從那 9 個字裡挑。
%[text] 區分方法：**用一段完全不同的文字測試同一個 CharacterSet。**
%[text] 若字元集限制是「真的幫助辨識」，那對其他文字應該沒有幫助甚至有害；
%[text] 若它只是「限縮選項」，那對任何文字都會輸出那 9 個字。
if strlength(usedFontZh) > 0
    otherText = "測試不同內容";
    [imgOther, ~] = ch15_makeCJKImage(otherText, 60);
    if ~isempty(imgOther)
        tStrict = ocr(imgOther, Model="chinesetraditional", ...
            CharacterSet=zhTruth);
        got = ch15_cleanText(tStrict.Text);
        fprintf("\n用「僅目標9字」的字元集去辨識另一段文字「%s」：\n", otherText);
        fprintf("  輸出：[%s]\n", got);
        stripped = char(replace(got, " ", ""));
        if isempty(stripped)
            fprintf("  輸出是**空的**。\n");
            fprintf("  **這比「輸出錯字」更能說明問題**：OCR 看到的字\n");
            fprintf("  全都不在字元集內，於是它什麼都不敢輸出。\n");
            fprintf("  證實 CharacterSet 只是「限縮選項」，\n");
            fprintf("  不會讓 OCR 看得更清楚。\n");
        else
            onlyTargetChars = all(ismember(stripped, char(zhTruth)));
            fprintf("  輸出是否只含那 9 個字？%s\n", string(onlyTargetChars));
            if onlyTargetChars
                fprintf("  **是** -> 證實 CharacterSet 是在「限縮選項」，\n");
                fprintf("  它不會讓 OCR 看得更清楚，只是不准它輸出別的字。\n");
            end
        end
    end
end
%[text] **實測數字（字型 MingLiU，九個字）**
%[text:table]
%[text] | CharacterSet | 40 pt | 60 pt | 80 pt | 100 pt |
%[text] | --- | --- | --- | --- | --- |
%[text] | 不限制 | 0.7778 | **0.5556** | **0.5556** | 0.6667 |
%[text] | 寬鬆（約 60 字） | 0.6667 | 0.5556 | 0.5556 | 0.5556 |
%[text] | 中等（20 字） | 0.6667 | 0.5556 | 0.5556 | 0.5556 |
%[text] | 嚴格（僅目標 9 字） | 0.6667 | 0.5556 | 0.5556 | 0.5556 |
%[text:table]
%[text] **第 5 小題：字級的改善是字元集的兩倍。**
%[text:table]
%[text] | 手段 | 從基準 0.7778 的最大改善 |
%[text] | --- | --- |
%[text] | **只加大字級** | **0.2222** |
%[text] | 只限制字元集 | 0.1111 |
%[text:table]
%[text] 而且三種字元集強度的結果**完全相同**——
%[text] 從「約 60 字」收到「僅 9 字」沒有任何額外好處。
%[text] 這說明字元集的幫助在**第一步**就用完了
%[text] （排除掉數千個不可能的字），再收緊沒有意義。
%[text] 另外注意 100 pt 的 CER（0.6667）比 60 pt（0.5556）**更差**。
%[text] 字級不是越大越好——太大時字元可能超出畫布或被切掉。
%[text] **最好的結果 0.5556 仍然是「九個字錯四個」。**
%[text] 兩種手段加起來都無法讓中文 OCR 變得可用，
%[text] 這強化了主教材第 8 節的結論：**中文場景要嘛自訓模型，要嘛改用條碼。**
%[text] **結論：`CharacterSet` 是一個強力但危險的工具。**
%[text] - **它有效**，因為它排除了大量不可能的候選
%[text] - **但它不會提升辨識能力**，只是限縮輸出空間
%[text] - **若真實內容超出字元集，它會強制輸出錯字**，而且信心值可能還很高
%[text] > **只有在你能保證內容一定落在字元集內時才用它。**
%[text] > 料號、車牌、日期這類**格式固定**的場景很適合；
%[text] > 自由文字則不適合。
%%
%[text] # 解答 4：可交付的料號讀取流程
%[text] 完整函式見本檔末的 `readPartNumber`。先看它的設計決定。
testCases = ["ABC-12345" "XYZ-98765" "QWE-11111" "RTY-24680" "ASD-13579"];
fontSizesPN = [24 28 32 24 28];
anglesPN    = [0 1 0 -1 0];

fprintf("\n%-14s %-14s %10s %10s %8s\n", ...
    "真實料號", "讀到的", "信心", "候選數", "正確?");
nCorrect = 0;
for k = 1:numel(testCases)
    A = makePartImage(testCases(k), fontSizesPN(k), anglesPN(k));
    r = readPartNumber(A);
    isOK = r.Status == "found" && r.PartNumber == testCases(k);
    nCorrect = nCorrect + isOK;
    fprintf("%-14s %-14s %10.4f %10d %8s\n", testCases(k), ...
        r.PartNumber, r.Confidence, r.NumCandidates, string(isOK));
end
fprintf("\n完全正確率 = %d / %d = %.1f%%" + "\n", ...
    nCorrect, numel(testCases), 100*nCorrect/numel(testCases));
%%
%[text] ## 第 8 小題：沒有料號的影像
%[text] **一個會亂猜的讀取器比讀不到更危險。**
noPN = ch15_makeTextImage("Hello World no code here", 28);
rNo = readPartNumber(noPN);
fprintf("\n沒有料號的影像：\n");
fprintf("  Status      = %s\n", rNo.Status);
fprintf("  PartNumber  = [%s]\n", rNo.PartNumber);
fprintf("  說明        = %s\n", rNo.Note);
assert(rNo.Status ~= "found", ...
    "讀取器在沒有料號的影像上回報了 found——它在亂猜。");
fprintf("\n**確認：回傳 not_found 而不是亂猜。**\n");

% 再測一個「像料號但格式不符」的情況
nearMiss = ch15_makeTextImage("AB-1234 and ABCD-123456", 28);
rNear = readPartNumber(nearMiss);
fprintf("\n格式相近但不符的影像（AB-1234 / ABCD-123456）：\n");
fprintf("  Status = %s、PartNumber = [%s]\n", rNear.Status, rNear.PartNumber);
%[text] **設計決定的理由**
%[text] 1. **明確的 `Status` 欄位**，不用空字串表示失敗。
%[text]    空字串會被呼叫端誤當成「讀到了但內容是空的」。
%[text] 2. **回報候選數**。只有一個候選與有五個候選（選了信心最高的）
%[text]    是完全不同的可信度，呼叫端需要知道。
%[text] 3. **用正規表達式做最後把關**。OCR 的輸出再髒，
%[text]    只要不符合 `[A-Z]{3}-\d{5}` 就不會被當成料號。
%[text]    這正是主教材第 9 節說的「雜訊用一行正規表達式就能濾掉」。
%[text] 4. **`CharacterSet` 限制成大寫字母、數字與連字號**，
%[text]    但**不限制成更嚴格的集合**——因為那會逼 OCR 亂猜（解答 3 的教訓）。
%%
%[text] # 解答 5：背景複雜度與兩階段的交叉點
%[text] **先修好一個參數，否則整個實驗會得到錯誤的結論。**
%[text] 主教材第 9 節已經說明：CRAFT 的框緊貼文字，
%[text] 對它用預設的 `LayoutAnalysis="auto"` 會讓 OCR 讀不到東西。
%[text] 這裡對 ROI 一律用 `"word"` 並加 8 px 的 padding。
if ~hasCRAFT
    fprintf("未安裝 Text Detection 模型，跳過解答 5。\n");
else
    sceneWords = ["ALPHA" "BRAVO" "CHARLIE" "DELTA"];
    bgLevels = ["純白" "淡雜紋" "強紋理" "強紋理+干擾"];

    precD = nan(size(bgLevels)); recD = nan(size(bgLevels));
    precC = nan(size(bgLevels)); recC = nan(size(bgLevels));
    nRegions = zeros(size(bgLevels));

    for b = 1:numel(bgLevels)
        scene = makeScene(sceneWords, b);

        % --- 直接 OCR ---
        [recD(b), precD(b)] = prf(normWords(ocr(scene).Words), sceneWords);

        % --- CRAFT 兩階段（正確的 LayoutAnalysis + padding）---
        bb = detectTextCRAFT(scene);
        nRegions(b) = size(bb,1);
        wC = strings(0);
        for k = 1:size(bb,1)
            r = bb(k,:) + [-8 -8 16 16];
            r(1) = max(1, r(1)); r(2) = max(1, r(2));
            t = ocr(imcrop(scene, r), LayoutAnalysis="word");
            wC = [wC; normWords(t.Words)];
        end
        [recC(b), precC(b)] = prf(wC, sceneWords);
    end

    fprintf("\n%-16s %8s %12s %12s %12s %12s\n", ...
        "背景", "CRAFT區域", "直接recall", "直接prec", "兩階段recall", "兩階段prec");
    for b = 1:numel(bgLevels)
        fprintf("%-16s %8d %11.1f%% %11.1f%% %11.1f%% %11.1f%%" + "\n", ...
            bgLevels(b), nRegions(b), recD(b), precD(b), recC(b), precC(b));
    end

    figure
    tiledlayout(1,2, TileSpacing="compact")
    nexttile
    plot(1:numel(bgLevels), recD, "o-", LineWidth=1.8, DisplayName="直接 OCR")
    hold on
    plot(1:numel(bgLevels), recC, "s-", LineWidth=1.8, DisplayName="兩階段")
    hold off
    set(gca, XTick=1:numel(bgLevels), XTickLabel=bgLevels)
    ylabel("Recall (%)"); ylim([-5 105])
    title("Recall"); legend(Location="southwest"); grid on
    nexttile
    plot(1:numel(bgLevels), precD, "o-", LineWidth=1.8, DisplayName="直接 OCR")
    hold on
    plot(1:numel(bgLevels), precC, "s-", LineWidth=1.8, DisplayName="兩階段")
    hold off
    set(gca, XTick=1:numel(bgLevels), XTickLabel=bgLevels)
    ylabel("Precision (%)"); ylim([-5 105])
    title("Precision"); legend(Location="southwest"); grid on

    cross = find(recC > recD, 1, "first");
    if isempty(cross)
        fprintf("\n在測試的四種背景下，兩階段的 recall 從未超過直接 OCR。\n");
    else
        fprintf("\n**兩階段的 recall 從「%s」開始勝出。**\n", bgLevels(cross));
    end
end
%[text] **第 5 小題：交叉點在「強紋理」，而且差距是斷崖式的。**
%[text:table]
%[text] | 背景 | 直接 recall | 直接 prec | **兩階段 recall** | **兩階段 prec** |
%[text] | --- | --- | --- | --- | --- |
%[text] | 純白 | 100.0% | 100.0% | 100.0% | 100.0% |
%[text] | 淡雜紋 | 100.0% | 100.0% | 100.0% | 100.0% |
%[text] | **強紋理** | **25.0%** | 100.0% | **100.0%** | 100.0% |
%[text] | **強紋理+干擾** | **0.0%** | 0.0% | **100.0%** | 100.0% |
%[text:table]
%[text] **兩階段在四種背景下全部維持 100% / 100%，
%[text] 而直接 OCR 從 100% 崩到 0%。**
%[text] 注意 CRAFT 在四種背景下**都找到 4 個區域**——
%[text] 偵測完全不受背景影響，因為它是訓練來找文字的。
%[text] 乾淨背景上兩者相同，兩階段只是多花了一次深度學習推論的時間。
%[text] 機制很清楚：
%[text] - **直接 OCR** 要在整張影像上做版面分析，紋理會被誤判成文字結構，
%[text]   切字階段就亂了
%[text] - **兩階段** 先用 CRAFT 把文字框出來，**背景在 OCR 之前就被裁掉了**
%[text] > **兩階段解決的是「背景干擾版面分析」這個特定問題。**
%[text] > 它不會讓字看得更清楚，也不會修好模糊或傾斜。
%[text] 所以選擇的判準很單純：**背景會不會干擾版面分析？**
%[text] 掃描文件不會（背景是白紙），場景照片會。
%[text] # 加分題：OCR 信心值能不能當品質門檻
%[text] 產生大量劣化樣本，看信心值與實際 CER 的關係。
gtBonus = "ABCDEFG 0123456789 Hello World";
baseBonus = ch15_makeTextImage(gtBonus, 28);

rng(0);
confs = []; cers = [];
kinds = strings(0);

% 混合各種劣化與強度
for sg = [0 0.5 1 1.5 2 2.5 3]
    A = baseBonus; if sg > 0, A = imgaussfilt(A, sg); end
    [c, e] = scoreImage(A, gtBonus);
    confs(end+1) = c; cers(end+1) = e; kinds(end+1) = "blur";
end
for ang = [0 0.5 1 1.5 2 3 5 8 12 16 20]
    A = baseBonus; if ang > 0, A = imrotate(A, ang, "bilinear", "crop"); end
    [c, e] = scoreImage(A, gtBonus);
    confs(end+1) = c; cers(end+1) = e; kinds(end+1) = "rotate";
end
for fs = [8 9 10 11 12 14 16 20 24 28 36]
    A = ch15_makeTextImage(gtBonus, fs);
    [c, e] = scoreImage(A, gtBonus);
    confs(end+1) = c; cers(end+1) = e; kinds(end+1) = "fontsize";
end
for v = [0 0.005 0.02 0.05 0.1 0.2]
    A = baseBonus; if v > 0, A = imnoise(A, "gaussian", 0, v); end
    [c, e] = scoreImage(A, gtBonus);
    confs(end+1) = c; cers(end+1) = e; kinds(end+1) = "noise";
end
for sc = [1 0.8 0.6 0.5 0.4 0.3 0.25]
    A = imresize(baseBonus, sc);
    [c, e] = scoreImage(A, gtBonus);
    confs(end+1) = c; cers(end+1) = e; kinds(end+1) = "downscale";
end

confs = confs(:); cers = cers(:);
valid = isfinite(confs) & isfinite(cers);
fprintf("\n樣本數 %d（其中 %d 個有有效信心值）\n", numel(confs), nnz(valid));

rho  = corr(confs(valid), cers(valid));
rhoS = corr(confs(valid), cers(valid), Type="Spearman");
fprintf("信心值 vs CER：Pearson %+.4f、Spearman %+.4f\n", rho, rhoS);
%%
%[text] ## ROC 與門檻選擇
failThresh = 0.1;
isFail = cers > failThresh;
fprintf("\n以 CER > %.2f 定義「失敗」：%d / %d 個樣本失敗\n", ...
    failThresh, nnz(isFail(valid)), nnz(valid));

cand = linspace(min(confs(valid)), max(confs(valid)), 60);
tpr = zeros(size(cand)); fpr = zeros(size(cand)); missed = zeros(size(cand));
for k = 1:numel(cand)
    flagged = confs(valid) < cand(k);        % 低於門檻 -> 判為「要重讀」
    f = isFail(valid);
    tpr(k) = nnz(flagged & f) / max(1, nnz(f));
    fpr(k) = nnz(flagged & ~f) / max(1, nnz(~f));
    missed(k) = nnz(~flagged & f);
end

figure
tiledlayout(1,2, TileSpacing="compact")
nexttile
scatter(confs(valid), cers(valid), 60, "filled")
yline(failThresh, "--", "失敗門檻", LineWidth=1.4);
xlabel("平均信心值"); ylabel("實際 CER")
title(sprintf("信心值 vs CER（r = %+.3f）", rho)); grid on
nexttile
plot(fpr, tpr, "o-", LineWidth=1.8)
hold on; plot([0 1],[0 1], "k--", DisplayName="隨機"); hold off
xlabel("誤殺率（好的被判要重讀）"); ylabel("抓到率（壞的被抓到）")
title("信心值門檻的 ROC"); grid on; axis square

% 挑一個抓到率 >= 0.9 且誤殺最少的門檻
goodIdx = find(tpr >= 0.9);
if isempty(goodIdx)
    fprintf("\n**找不到能抓到 90%% 失敗的門檻。**\n");
    [~, best] = max(tpr - fpr);
else
    [~, mi] = min(fpr(goodIdx));
    best = goodIdx(mi);
end
fprintf("\n建議門檻：信心 < %.4f 就重讀\n", cand(best));
fprintf("  抓到率 %.1f%%、誤殺率 %.1f%%、漏抓 %d 個\n", ...
    100*tpr(best), 100*fpr(best), missed(best));
%[text] **第 6 小題：信心值比 NIQE 更能預測任務失敗嗎？**
%[text] **有相關，但不足以當單一門檻。** 實測：
%[text:table]
%[text] | 項目 | 數值 |
%[text] | --- | --- |
%[text] | 信心值 vs CER 的 Pearson 相關 | **−0.5668** |
%[text] | Spearman 相關 | −0.5462 |
%[text] | 樣本數 | 42（37 個有有效信心值） |
%[text:table]
%[text] 負相關符合預期（信心越低、錯誤越多），
%[text] 而 **|r| ≈ 0.57 明顯優於第 12 章的 NIQE**——
%[text] 那裡品質指標與任務結果幾乎沒有關係。
%[text] **但門檻選擇的結果很難看：**
%[text:table]
%[text] | 門檻 | 抓到率 | **誤殺率** |
%[text] | --- | --- | --- |
%[text] | 信心 < 0.9568 | 100.0% | **96.6%** |
%[text:table]
%[text] 要抓到全部的失敗，就得把**幾乎每一張**都判為「要重讀」。
%[text] 原因是兩個分布**重疊太多**：很多 CER=0 的樣本信心值也不高
%[text] （例如小字但仍讀對），而少數 CER 很高的樣本信心值卻不低。
%[text] > **相關係數 −0.57 代表「有訊號」，不代表「可以當門檻」。**
%[text] > 這兩件事要分開判斷：畫 ROC 看實際的取捨，
%[text] > 不要只看相關係數就下結論。
%[text] 為什麼它仍然比 NIQE 好：**它量的是同一件事。**
%[text] 第 12 章的 NIQE 量的是「影像像不像自然照片」——
%[text] 那與「OCR 讀不讀得出來」之間沒有因果關係，
%[text] 所以同一個 NIQE 值對應到完全不同的任務結果。
%[text] OCR 的信心值則是**辨識器自己對自己輸出的評估**。
%[text] 它與 CER 之間有真實的機制連結：
%[text] 字元與模板不相似時，信心值下降、辨識也更可能出錯。
%[text] **但它仍然不是完美的：**
%[text] - 信心值**不知道自己漏讀了什麼**。整段文字沒被偵測到時，
%[text]   剩下的字可能信心都很高——這是主教材第 9 節 CRAFT
%[text]   recall 只有 33% 卻 precision 80% 的同一個問題
%[text] - `CharacterSet` 限制會**人為抬高信心值**（解答 3），
%[text]   因為候選變少了
%[text] > **實務建議：信心值適合當「重讀」的觸發條件，
%[text] > 但不能當「這次讀對了」的證明。**
%[text] > 要證明讀對了，只能靠**格式驗證**（解答 4 的正規表達式）
%[text] > 或**冗餘**（校驗碼、重複讀取比對）——
%[text] > 而那正是條碼比 OCR 可靠的根本原因（第 1 節）。

% ========================================================================
function tf = decodes(A)
try
    m = readBarcode(A);
    tf = strlength(string(m)) > 0;
catch
    tf = false;
end
end

% ========================================================================
function A = makeTextWithFont(txt, fontSize, fontName)
canvas = uint8(255*ones(round(fontSize*3), round(fontSize*strlength(txt)*0.8)+20, 3));
A = insertText(canvas, [10 fontSize], txt, Font=fontName, ...
    FontSize=fontSize, TextColor="black", BoxOpacity=0);
end

% ========================================================================
function h = measureGlyphHeight(A)
%MEASUREGLYPHHEIGHT 量實際的字元像素高度（取各連通元件高度的中位數）。
%
%   用中位數而非平均：標點與有上下延伸的字母（如 g、l）會拉偏平均。
bw = ~imbinarize(im2gray(A));
bw = bwareaopen(bw, 4);
st = regionprops("table", bw, "BoundingBox");
if isempty(st)
    h = NaN;
    return
end
h = median(st.BoundingBox(:,4));
end

% ========================================================================
function A = makePartImage(pn, fontSize, angleDeg)
A = ch15_makeTextImage(pn, fontSize);
if angleDeg ~= 0
    A = imrotate(A, angleDeg, "bilinear", "crop");
end
end

% ========================================================================
function result = readPartNumber(I, options)
%READPARTNUMBER 讀取 ABC-12345 格式的料號，並明確回報讀不到的狀態。
%
%   RESULT = READPARTNUMBER(I) 回傳 struct：
%     PartNumber     讀到的料號（讀不到時為 ""）
%     Confidence     該料號的平均字元信心
%     Status         "found" / "not_found"
%     NumCandidates  符合格式的候選數
%     RawText        OCR 的原始輸出（供偵錯）
%     Note           人類可讀的說明
%
%   設計決定
%   --------
%   **① 用明確的 Status 而不是空字串。**
%   空字串會被呼叫端誤當成「讀到了但是空的」。一個回傳值同時
%   表示「失敗」與「成功但內容為空」是很糟的介面。
%
%   **② 回報候選數。** 只有一個候選與有五個候選（選了信心最高的）
%   是完全不同的可信度，呼叫端必須知道。
%
%   **③ 用正規表達式做最後把關。** OCR 輸出再髒，不符合
%   [A-Z]{3}-\d{5} 就不會被當成料號。這是第 15 章第 9 節
%   「雜訊用一行正規表達式就能濾掉」的實作。
%
%   **④ CharacterSet 只限制到字元類別，不限制到具體字串。**
%   解答 3 證明過度限制會逼 OCR 亂猜——它只是限縮輸出空間，
%   不會提升辨識能力。

arguments
    I {mustBeNumeric, mustBeNonempty}
    % **必須加詞邊界。** 沒有邊界時 "ABCD-123456" 會被誤匹配出
    % "BCD-12345"——實測踩過這個坑。
    options.Pattern (1,1) string = "\<[A-Z]{3}-\d{5}\>"
    options.CharacterSet (1,1) string = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-"
end

txt = ocr(I, CharacterSet=char(options.CharacterSet));
raw = ch15_cleanText(txt.Text);

% 從原始輸出中萃取所有符合格式的候選
cands = string(regexp(raw, options.Pattern, "match"));

result = struct("PartNumber", "", "Confidence", NaN, ...
    "Status", "not_found", "NumCandidates", numel(cands), ...
    "RawText", raw, "Note", "");

if isempty(cands)
    result.Note = "OCR 輸出中沒有符合 " + options.Pattern + " 的字串。" + ...
        "原始輸出：[" + raw + "]";
    return
end

% 多個候選時取信心最高的
words = string(txt.Words);
confsW = txt.WordConfidences;
bestConf = -Inf; bestPN = cands(1);
for k = 1:numel(cands)
    idx = find(contains(words, cands(k)), 1);
    if isempty(idx)
        c = NaN;
    else
        c = confsW(idx);
    end
    if isnan(c), c = 0; end
    if c > bestConf
        bestConf = c; bestPN = cands(k);
    end
end

result.PartNumber = bestPN;
result.Confidence = bestConf;
result.Status = "found";
if numel(cands) > 1
    result.Note = sprintf("有 %d 個候選，已取信心最高者。其餘：%s", ...
        numel(cands), join(cands(cands ~= bestPN), ", "));
else
    result.Note = "唯一候選。";
end
end

% ========================================================================
function scene = makeScene(words, level)
%MAKESCENE 造背景複雜度遞增的合成場景，文字內容已知。
H = 300; W = 520;
switch level
    case 1
        bg = uint8(250*ones(H, W, 3));
    case 2
        bg = im2uint8(0.92 + 0.05*randn(H, W, 3));
    case 3
        f = imresize(imread("fabric.png"), [H W]);
        bg = im2uint8(0.45 + 0.5*im2double(f));
    case 4
        f = imresize(imread("fabric.png"), [H W]);
        bg = im2uint8(0.45 + 0.5*im2double(f));
        for k = 1:6
            r = randi([20 H-60]); c = randi([20 W-60]);
            bg(r:r+40, c:c+40, :) = uint8(randi([0 255]));
        end
end
positions = [30 40; 30 110; 30 180; 30 250];
scene = bg;
for k = 1:numel(words)
    scene = insertText(scene, positions(k,:), words(k), FontSize=34, ...
        TextColor="black", BoxColor="white", BoxOpacity=1);
end
end

% ========================================================================
function w = normWords(words)
w = upper(strtrim(string(words(:))));
w = w(strlength(w) > 0);
if isempty(w), return, end
keep = ~cellfun(@isempty, regexp(cellstr(w), "[A-Z0-9]", "once"));
w = w(keep);
end

% ========================================================================
function [recallPct, precisionPct] = prf(found, truth)
if isempty(found)
    recallPct = 0; precisionPct = 0;
    return
end
recallPct    = 100 * nnz(ismember(truth, found)) / numel(truth);
precisionPct = 100 * nnz(ismember(found, truth)) / numel(found);
end

% ========================================================================
function [c, e] = scoreImage(A, gt)
t = ocr(A);
c = mean(t.WordConfidences, "omitnan");
if isempty(c), c = NaN; end
e = ch15_cer(ch15_cleanText(t.Text), gt);
end

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline","rightPanelPercent":40}
%---
