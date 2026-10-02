%[text] # 第 15 章　符碼、文字偵測與 OCR
%[text] {"align":"left"}IPCV\_Lab 課程教材　｜　MATLAB R2026b　｜　難度：\[基礎\]　｜　建議時數：3 小時
%[text] ## 學習目標
%[text] 讀完本章並完成練習後，你應該能夠：
%[text] 1. 用 `readBarcode` 讀取一維與二維條碼，並說出**兩者的耐受度差在哪裡**
%[text] 2. 用**合成文字**建立精確的 ground truth，並以字元錯誤率（CER）評估 OCR
%[text] 3. 說出 OCR 最怕的劣化是什麼——答案與直覺相反
%[text] 4. 選擇 `LayoutAnalysis`，並知道選錯會讓輸出歸零
%[text] 5. 使用繁體中文 OCR，並**誠實評估它的實際表現**
%[text] 6. 比較 `detectTextCRAFT` 兩階段流程與直接 OCR 的 precision／recall 取捨 \
%[text] ## 前置知識
%[text] 第 03 章（對比與二值化）、第 12 章（劣化與指標的觀念）。
%[text] ## 環境需求
assert(exist("checkEnvironment","file") == 2, ...
    "請先切換到課程根目錄並執行 ipcvSetup，再回來執行本章。");
checkEnvironment(Chapters="15");
hasCRAFT = exist("detectTextCRAFT", "file") > 0;
rng(0);
%%
%[text] # 1. 這一章的位置
%[text] 前面十四章的輸出都是**數字或遮罩**。這一章的輸出是**字串**——
%[text] 而字串有一個特別的性質：**它要嘛對，要嘛錯，沒有「差不多」。**
%[text] 一個料號讀錯一個字元，整筆資料就是廢的。
%[text] 這改變了評估方式：不能再用 PSNR 那種連續指標，
%[text] 要用**字元錯誤率**（CER）或**完全比對率**。
%[text] 三種取得結構化資訊的方式，難度遞增：
%[text:table]
%[text] | 方式 | 內容有沒有冗餘 | 可靠度 |
%[text] | --- | --- | --- |
%[text] | **條碼／QR** | 有（含錯誤更正碼） | 極高，讀到就幾乎一定對 |
%[text] | **印刷文字 OCR** | 無 | 中等，需要好的影像 |
%[text] | **場景文字 OCR** | 無，而且背景複雜 | 低，通常要兩階段 |
%[text:table]
%[text] > **能用條碼就不要用 OCR。** QR 碼有 Reed–Solomon 錯誤更正，
%[text] > 髒污、破損、旋轉都還讀得出來；OCR 沒有這種保護。
%%
%[text] # 2. 條碼：`readBarcode`
QR  = imread("barcodeQR.jpg");
EAN = imread("barcode1D.jpg");

[msgQR,  fmtQR,  locQR]  = readBarcode(QR);
[msgEAN, fmtEAN, locEAN] = readBarcode(EAN);

fprintf("\nQR  格式 %-10s 內容：%s\n", string(fmtQR), string(msgQR));
fprintf("1D  格式 %-10s 內容：%s\n", string(fmtEAN), string(msgEAN));
fprintf("\nQR  回傳的定位點 %s（四個角）\n", mat2str(size(locQR)));
fprintf("1D  回傳的定位點 %s（兩個端點）\n", mat2str(size(locEAN)));

figure
tiledlayout(1,2, TileSpacing="compact")
nexttile
imshow(insertShape(QR, "polygon", locQR(:)', Color="green", LineWidth=4));
title(sprintf("%s", string(fmtQR)))
nexttile
imshow(insertShape(EAN, "line", locEAN(:)', Color="green", LineWidth=4));
title(sprintf("%s：%s", string(fmtEAN), string(msgEAN)))
%[text] 回傳的第三個輸出是**定位資訊**，而兩種碼的形狀不同：
%[text] - **QR**：`[4 2]`，四個角點——因為 QR 是二維的，需要完整的四角定位
%[text] - **1D**：`[2 2]`，兩個端點——一維條碼只需要知道掃描線的起終點
%[text] 這個差異直接反映在下一節的耐受度上。
%%
%[text] # 3. 條碼的耐受度：找出它什麼時候會失敗
%[text] 「能讀」不是規格，「在什麼條件下能讀」才是。
%[text] 下面掃四種劣化，記錄**失敗點**。
robustTbl = ch15_barcodeRobustness(QR, EAN);
disp(robustTbl)
%[text] 實測結果：
%[text:table]
%[text] | 劣化 | QR 失敗點 | EAN-13 失敗點 |
%[text] | --- | --- | --- |
%[text] | **旋轉** | **完全不失敗**（0–180° 全通過） | **30°、45°、90° 失敗** |
%[text] | 高斯模糊 | σ = 6 | σ = 6 |
%[text] | 對比壓縮 | 0.08 | 0.08 |
%[text] | 縮小 | 0.15 倍 | 0.15 倍 |
%[text:table]
%[text] **旋轉那一列是唯一有差異的，而差異很大。**
%[text:table]
%[text] | 角度 | QR | EAN-13 |
%[text] | --- | --- | --- |
%[text] | 0° | OK | OK |
%[text] | 15° | OK | OK |
%[text] | **30°** | OK | **失敗** |
%[text] | **45°** | OK | **失敗** |
%[text] | **90°** | OK | **失敗** |
%[text] | **180°** | OK | **OK** |
%[text:table]
%[text] 原因在編碼方式：
%[text] - **QR 有三個「回」字形的定位圖案（finder pattern）**，
%[text]   解碼器先找到它們就能推出方向，所以任何角度都行。
%[text] - **1D 條碼是沿著一條掃描線讀粗細**。掃描線一旦不與條碼垂直，
%[text]   讀到的就是被拉長的錯誤寬度。
%[text] - **180° 例外**：那只是把掃描線反過來讀，序列反轉後仍可解碼。
%[text] > **實務結論：會被任意擺放的物件（例如輸送帶上的料件）必須用 QR，
%[text] > 或者用機構固定方向。**
%[text] 其餘三種劣化兩者的失敗點**完全相同**——
%[text] 因為模糊、低對比、低解析度破壞的是「黑白邊界」本身，
%[text] 那是兩種碼共同的基礎。
%%
%[text] # 4. OCR 的評估：用合成文字取得精確答案
%[text] OCR 的教學常見問題是「辨識出來了，看起來還行」。
%[text] **那不是評估。** 這一節建立一個能給出精確數字的做法：
%[text] **用 `insertText` 產生文字影像，那段字串就是 ground truth。**
groundTruth = "ABCDEFG 0123456789 Hello World";
clean = ch15_makeTextImage(groundTruth, 28);

txt = ocr(clean);
fprintf("\nground truth ：[%s]\n", groundTruth);
fprintf("OCR 辨識結果 ：[%s]\n", ch15_cleanText(txt.Text));
fprintf("字元錯誤率 CER = %.4f\n", ch15_cer(ch15_cleanText(txt.Text), groundTruth));
fprintf("平均字詞信心    = %.4f\n", mean(txt.WordConfidences, "omitnan"));

figure
imshow(clean); title(sprintf("合成文字（CER %.4f）", ...
    ch15_cer(ch15_cleanText(txt.Text), groundTruth)))
%[text] **CER（Character Error Rate）** = 編輯距離 / 參考字串長度。
%[text] 0 代表完全正確，1 代表全錯。用 `editDistance` 計算。
%[text] 為什麼用 CER 而不是「有沒有完全一樣」：
%[text] 完全比對只給 0 或 1，看不出「錯一個字」與「全錯」的差別，
%[text] 掃描參數時整條曲線會是階梯狀，無法判斷趨勢。
%%
%[text] # 5. OCR 最怕什麼——答案與直覺相反
degradeTbl = ch15_ocrDegradation(groundTruth);
disp(degradeTbl)
%[text] 四種劣化各自掃一遍（CER，0 = 完全正確）：
%[text] **① 字級大小：小於 14 就開始錯**
%[text:table]
%[text] | FontSize | CER | 平均信心 |
%[text] | --- | --- | --- |
%[text] | **10** | **0.1000** | 0.6114 |
%[text] | 14 | 0.0000 | 0.9177 |
%[text] | 24 | 0.0000 | 0.9524 |
%[text] | 48 | 0.0000 | 0.9520 |
%[text:table]
%[text] **② 模糊：到 σ=2 都完全正確，σ=3 直接全錯**
%[text:table]
%[text] | σ | CER |
%[text] | --- | --- |
%[text] | 0–2 | **0.0000** |
%[text] | **3** | **1.0000** |
%[text:table]
%[text] 不是逐漸變差，是**懸崖**。σ=2 還 100% 正確，σ=3 完全讀不出來。
%[text] **③ 雜訊：完全免疫**
%[text:table]
%[text] | variance | CER |
%[text] | --- | --- |
%[text] | 0 → 0.06 | **全部 0.0000** |
%[text:table]
%[text] 加到 variance 0.06（已經很髒）**CER 仍然是 0**，信心值也沒掉
%[text] （0.9455 → 0.9508）。
%[text] **④ 旋轉：2 度就毀了**
%[text:table]
%[text] | 角度 | CER | 平均信心 |
%[text] | --- | --- | --- |
%[text] | 0° | 0.0000 | 0.9455 |
%[text] | 1° | 0.0667 | 0.9500 |
%[text] | **2°** | **0.3667** | 0.6214 |
%[text] | 5° | 0.1667 | 0.6356 |
%[text] | 10° | **0.9667** | 0.4175 |
%[text] | 20° | 0.8667 | 0.1757 |
%[text:table]
%[text] 注意 CER 不是單調的（2° 的 0.3667 比 5° 的 0.1667 還糟，
%[text] 20° 又比 10° 好）。小角度時字元框「剛好」重疊得最嚴重；
%[text] 更大的角度反而讓版面分析改用不同的切法。
%[text] **所以不能只測兩三個角度就下結論**——要掃出整條曲線。
%[text] 但**信心值是單調下降的**（0.9455 → 0.1757），
%[text] 它比 CER 更早、更一致地反映出問題。
%[text] > **這是本章最重要的實測結果：**
%[text] > **OCR 幾乎完全不怕雜訊，卻會被 2 度的傾斜毀掉。**
%[text] > （2° 的 CER 0.3667 vs 雜訊 variance 0.06 的 CER 0.0000）
%[text] 原因：OCR 先把影像二值化再切出字元框。
%[text] - **雜訊**是高頻的，二值化時被門檻直接壓掉，字形結構完好
%[text] - **傾斜**會讓同一行文字的字元框**互相重疊**，
%[text]   切字階段就錯了，後面再準也沒用
%[text] **實務優先順序因此是：**
%[text] 1. **先確保文字是正的**（機構固定、或自動校正傾斜）
%[text] 2. **再確保字夠大**（至少 14 pt 等效，掃描建議 300 dpi 以上）
%[text] 3. **對焦要準**（σ=3 就是懸崖）
%[text] 4. **去雜訊優先度最低**——它幾乎不影響 OCR
%[text] 注意第 4 點與一般影像處理的直覺相反。
%[text] 第 12 章證明過去雜訊會讓無參考指標「變差」；
%[text] 這裡則是去雜訊對 OCR **沒有幫助**。
%[text] **不要把力氣花在不影響結果的前處理上。**
%%
%[text] # 6. 前處理：沒有萬用組合
%[text] 既然不同劣化的機制不同，前處理也不該一視同仁。
%[text] **重點：前處理必須在「真的會失敗」的輸入上測。**
%[text] 在一個本來就 CER=0 的影像上比較前處理方法，
%[text] 五種方法都會得到 0，什麼也分不出來。
preTbl = ch15_preprocessComparison(groundTruth);
disp(preTbl)
%[text] 實測（每格是 CER，越小越好）：
%[text:table]
%[text] | 劣化情況 | 無 | `imbinarize` | 放大2倍 | 放大2倍+binarize | `imsharpen` |
%[text] | --- | --- | --- | --- | --- | --- |
%[text] | 小字 FontSize=10 | 0.1000 | 0.1667 | **0.0000** | 0.0333 | 0.0667 |
%[text] | 重度模糊 σ=3 | 1.0000 | 1.0000 | 1.0000 | 1.0000 | 1.0000 |
%[text] | 傾斜 2° | 0.3667 | 0.4333 | 0.4333 | 0.3667 | **0.3000** |
%[text] | 傾斜 10° | 0.9667 | 0.9333 | 0.3667 | **0.3333** | 1.0333 |
%[text:table]
%[text] 四個結論：
%[text] **① 放大 2 倍完美修好小字（0.1000 → 0.0000）。**
%[text] 小字的問題是「每個字元的像素太少」，放大直接解決它。
%[text] **② 同樣的放大對 2° 傾斜沒有幫助（0.3667 → 0.4333，略差），
%[text] 對 10° 傾斜卻大幅改善（0.9667 → 0.3667）。**
%[text] 同一個方法在同一種劣化的不同強度下效果相反——
%[text] 這就是為什麼不能有「標準前處理流程」。
%[text] **③ `imsharpen` 在 2° 時最好（0.3000），在 10° 時最差（1.0333）。**
%[text] 銳化會強化字元邊緣，但也會強化重疊處的假邊緣。
%[text] **④ 重度模糊 σ=3 沒有任何前處理救得回來**（全部 1.0000）。
%[text] 資訊已經消失了——這是第 12 章「參數調到死也救不回一張糊掉的影像」
%[text] 的具體案例。
%[text] 另外注意 `imbinarize` **在四種情況下沒有一次是最好的**。
%[text] 因為 `ocr` 內部本來就會做二值化，而且它的方法更適合文字。
%[text] > **沒有「OCR 前處理標準流程」這種東西。**
%[text] > 要先知道你的影像是**哪一種**壞，才知道要用哪一種前處理。
%%
%[text] ## 6.1 自動校正傾斜：一個誠實的負面結果
%[text] 既然傾斜最致命，自動校正應該最有價值。**實測沒有。**
skewTbl = ch15_deskewEvaluation(groundTruth);
disp(skewTbl)
%[text] 用霍夫變換估文字基線的角度再轉回來：
%[text:table]
%[text] | 真實角度 | 估到的角度 | CER（未校正） | CER（校正後） | 變好？ |
%[text] | --- | --- | --- | --- | --- |
%[text] | 1° | −1.2 | 0.0667 | 0.3000 | ✗ |
%[text] | **2°** | −2.1 | 0.3667 | **0.1000** | ✓ |
%[text] | 5° | −5.4 | 0.1667 | 1.0000 | ✗ |
%[text] | **10°** | −10.0 | 0.9667 | **0.8667** | ✓ |
%[text] | 15° | −12.8 | 0.7000 | 0.9333 | ✗ |
%[text] | 20° | −18.2 | 0.8667 | 1.0000 | ✗ |
%[text:table]
%[text] **角度估得很準**——平均誤差只有 0.78 度，最大 2.20 度
%[text] （−1.2 / −2.1 / −5.4 / −10.0 對上 1 / 2 / 5 / 10）。
%[text] **但六個角度中只有兩個校正後變好。**
%[text] 原因是**重新取樣的代價**：
%[text] - 測試影像已經被 `imrotate` 轉過一次（內插 #1）
%[text] - 校正又轉一次（內插 #2）
%[text] - 兩次雙線性內插把字形邊緣抹糊，損失大於對齊的收益
%[text] > **估對角度不等於修好問題。** 修正動作本身也有代價。
%[text] 實務上的正確做法是**不要讓影像被轉兩次**：
%[text] 在**原始拍攝**的影像上估角度並只轉一次，
%[text] 或者更好——**用機構把待測物固定正**，根本不需要轉。
%[text] 這也解釋了為什麼產線的 OCR 幾乎都配治具。
%%
%[text] # 7. `LayoutAnalysis`：選錯會讓輸出歸零
card = imread("businessCard.png");
figure
imshow(card); title("businessCard.png")

fprintf("\n%-14s %10s %14s\n", "LayoutAnalysis", "字數", "平均信心");
for la = ["auto" "page" "block" "line" "word" "character" "none"]
    t = ocr(card, LayoutAnalysis=la);
    fprintf("%-14s %10d %14.4f\n", la, numel(t.Words), ...
        mean(t.WordConfidences, "omitnan"));
end
%[text] 實測：
%[text:table]
%[text] | LayoutAnalysis | 字數 | 平均信心 |
%[text] | --- | --- | --- |
%[text] | `auto`（預設） | 16 | 0.9185 |
%[text] | `page` | 16 | 0.9185 |
%[text] | `block` | 14 | **0.9233** |
%[text] | **`line`** | **0** | NaN |
%[text] | `word` | 1 | 0.4928 |
%[text] | `character` | 1 | 0.2477 |
%[text] | `none` | 1 | 0.4928 |
%[text:table]
%[text] **`line` 在這張名片上得到 0 個字。** 不是品質差，是完全沒有輸出。
%[text] `word`、`character`、`none` 也一樣崩潰（只剩 1 個字）。
%[text] 原因：這些選項是在告訴 OCR「**整張影像就是一個 X**」——
%[text] `word` 代表「整張圖是一個單字」、`line` 代表「整張圖是一行」。
%[text] 名片有多行多區塊，這些假設全錯。
%[text] **怎麼選：**
%[text:table]
%[text] | 你的影像 | 該用 |
%[text] | --- | --- |
%[text] | 掃描的整頁文件 | `page` 或 `auto` |
%[text] | 一個文字區塊（已裁切） | `block` |
%[text] | 已裁切的單行（例如車牌） | `line` |
%[text] | 已裁切的單一字詞 | `word` |
%[text] | 七段顯示器的單一數字 | `character` |
%[text:table]
%[text] > **`LayoutAnalysis` 描述的是「你餵進去的是什麼」，不是「你想要什麼」。**
%[text] > 這是初學者最常搞反的一個參數。
%[text] 第 9 節的 CRAFT 兩階段流程就是先把文字區域裁出來，
%[text] 再對每個區域用 `word` 或 `line`——那時這些選項才會發揮作用。
%%
%[text] # 8. 繁體中文 OCR：誠實的評估
%[text] `Computer Vision Toolbox OCR Language Data` 支援包提供 60 幾種語言，
%[text] 其中包含繁體中文。**注意名稱：**
%[text:table]
%[text] | 寫法 | 結果 |
%[text] | --- | --- |
%[text] | `Model="chinesetraditional"` | ✅ 可用 |
%[text] | `Model="chi_tra"` | ❌ `Invalid language character vector` |
%[text] | `Model="chinese-traditional"` | ❌ 同上 |
%[text:table]
%[text] `chi_tra` 是**檔名**（`chi_tra.traineddata`），不是 API 名稱。
zhTruth = "影像處理與電腦視覺";
[zhImg, usedFont] = ch15_makeCJKImage(zhTruth, 40);

if isempty(zhImg)
    fprintf("\n找不到支援中日韓的字型，跳過本節。\n");
else
    fprintf("\n使用字型：%s\n", usedFont);
    fprintf("ground truth：[%s]\n\n", zhTruth);
    figure
    imshow(zhImg); title("合成繁體中文（字型：" + usedFont + "）")

    fprintf("%-22s %10s  %s\n", "Model", "CER", "辨識結果");
    for m = ["english" "chinesetraditional" "chinesesimplified"]
        t = ocr(zhImg, Model=m);
        got = ch15_cleanText(t.Text);
        fprintf("%-22s %10.4f  [%s]\n", m, ch15_cer(got, zhTruth), got);
    end
end
%[text] 實測（`MingLiU` 40 pt，九個字）：
%[text:table]
%[text] | Model | CER | 辨識結果 |
%[text] | --- | --- | --- |
%[text] | `english` | 1.0000 | `AGEN` |
%[text] | **`chinesetraditional`** | **0.7778** | `影像 處 惠` |
%[text] | `chinesesimplified` | 0.7778 | `影像 处 理` |
%[text:table]
%[text] > **繁體中文模型的 CER 是 0.7778——九個字只讀對兩個。**
%[text] 這是一個**必須誠實說出來的結果**。網路上的教學通常只示範
%[text] 「它可以辨識中文」，不給錯誤率。
%[text] 為什麼這麼差：
%[text] - **中文字元集有數千個**，而英文只有 26×2 + 數字
%[text]   —— 混淆的機會多了兩個數量級
%[text] - **中文字的筆畫密度高**，同樣字級下每個筆畫佔的像素更少。
%[text]   40 pt 對英文很充裕，對「覺」這種 20 畫的字遠遠不夠
%[text] - Tesseract 的中文模型主要訓練於**掃描的印刷文件**，
%[text]   與這裡的合成點陣文字分布不同（第 12 章的領域落差問題）
%[text] **實務建議：**
%[text] 1. **字級要大很多**——中文建議至少英文的 2–3 倍
%[text] 2. **用 `CharacterSet` 限制字元集**。若只會出現特定的料號或地名，
%[text]    把可能的字列出來，錯誤率會大幅下降
%[text] 3. **考慮自訓模型**（第 8.1 節）
%[text] 4. **能用條碼就用條碼**——第 1 節的結論在這裡特別成立
%%
%[text] ## 8.1 R2023b 起：OCR 訓練流程已經換掉了
%[text] 舊教材（與大量網路資料）用的是 `ocrTrainer` APP 搭配
%[text] Tesseract 的 `.traineddata`。
%[text] **`ocrTrainer` 在 R2026a 已經不存在了：**
fprintf("\nocrTrainer 是否存在：%d\n", exist("ocrTrainer", "file"));
fprintf("locateText 是否存在：%d\n", exist("locateText", "file"));
fprintf("\n新的訓練工作流：\n");
for f = ["ocrTrainingData" "ocrTrainingOptions" "trainOCR" ...
         "evaluateOCR" "quantizeOCR" "ocrMetrics"]
    fprintf("  %-22s %d\n", f, exist(f, "file") > 0);
end
%[text] 兩個舊 API 都**已移除**：`ocrTrainer` 與 `locateText` 的 `exist` 都回傳 0。
%[text] 取而代之的是一組函式：
%[text:table]
%[text] | 函式 | 用途 |
%[text] | --- | --- |
%[text] | **Image Labeler** APP | 標註文字區域與內容（取代 `ocrTrainer` 的標註功能） |
%[text] | `ocrTrainingData` | 把標註轉成訓練資料 |
%[text] | `ocrTrainingOptions` | 設定訓練參數 |
%[text] | `trainOCR` | 訓練自訂 OCR 模型 |
%[text] | `evaluateOCR` | 用 `ocrMetrics` 評估（會給 CER／WER） |
%[text] | `quantizeOCR` | 量化模型以加速推論 |
%[text:table]
%[text] 典型流程：
%[text] ```matlab
%[text] % 1. 在 Image Labeler 中標註，匯出 groundTruth 物件
%[text] % 2. 轉成訓練資料
%[text] trainData = ocrTrainingData(gTruth, "text", "text");
%[text] % 3. 訓練
%[text] opts  = ocrTrainingOptions(OutputLocation=tempdir);
%[text] model = trainOCR(trainData, "myModel", "english", opts);
%[text] % 4. 評估（注意：要用**沒有參與訓練**的資料）
%[text] metrics = evaluateOCR(testData, model);
%[text] % 5. 使用
%[text] txt = ocr(I, Model=model);
%[text] ```
%[text] > **`evaluateOCR` 直接給 CER 與 WER**，
%[text] > 所以你不必像本章第 4 節那樣自己寫評估函式——
%[text] > 但自己寫過一次，才知道那個數字是什麼意思。
%[text] 本章不做完整訓練（需要大量標註資料），第 17 章會回到標註流程。
%%
%[text] # 9. 場景文字：CRAFT 兩階段 vs 直接 OCR
%[text] 名片與掃描文件的背景乾淨。**場景文字**（招牌、路標、產品包裝）
%[text] 背景複雜，直接丟給 `ocr` 通常會得到一堆雜訊。
%[text] R2026a 提供 `detectTextCRAFT`（深度學習的文字區域偵測），
%[text] 可以先把文字框出來再逐區辨識。
if ~hasCRAFT
    fprintf("\n未安裝 Text Detection 模型，跳過第 9 節。\n");
else
    sign = imread("handicapSign.jpg");
    bboxes = detectTextCRAFT(sign);

    figure
    tiledlayout(1,2, TileSpacing="compact")
    nexttile; imshow(sign); title("原圖")
    nexttile
    imshow(insertShape(sign, "rectangle", bboxes, Color="yellow", LineWidth=3));
    title(sprintf("detectTextCRAFT 找到 %d 個區域", size(bboxes,1)))

    cmpTbl = ch15_compareTextPipelines(sign, bboxes);
    disp(cmpTbl)
end
%[text] 用人工標註這張路標的 12 個字詞當 ground truth
%[text] （`PARKING SPECIAL PLATE REQUIRED UNAUTHORIZED VEHICLES
%[text] MAY BE TOWED AT OWNERS EXPENSE`）：
%[text] 用人工標註這張路標的 12 個字詞當 ground truth，
%[text] 並且**刻意把兩階段做兩次**——一次用正確的 `LayoutAnalysis`，
%[text] 一次用預設值：
%[text:table]
%[text] | 流程 | 輸出字數 | 命中 | **Recall** | **Precision** |
%[text] | --- | --- | --- | --- | --- |
%[text] | 直接 `ocr` | 14 | 11 / 12 | **91.7%** | 78.6% |
%[text] | **兩階段（`word` + padding）** | 12 | 10 / 12 | **83.3%** | **83.3%** |
%[text] | 兩階段（預設 `auto`） | 11 | 8 / 12 | 66.7% | 72.7% |
%[text:table]
%[text] **第三列與第二列的差別只有一個參數，recall 差了 16.6 個百分點。**
%[text] ### 一個我自己踩過的坑
%[text] 這一節的結論改過一次，而且改動很大。
%[text] 第一版用預設的 `LayoutAnalysis="auto"` 對 CRAFT 的框做 OCR，
%[text] 得到「兩階段 recall 只有 **33.3%**」，
%[text] 我差點把「兩階段沒有用」寫進教材。
%[text] **那個數字不是 CRAFT 的問題，是參數用錯了。**
%[text] CRAFT 回傳的框**緊貼文字**。對這種框說 `"auto"`，
%[text] 等於告訴 OCR「這是一整頁文件，請做版面分析」——
%[text] 然後它在一個只有一個單字的影像上找不到任何版面結構。
%[text] 合成場景（四個單字、白底）的對照實驗把這件事講得很清楚：
%[text:table]
%[text] | ROI 的 `LayoutAnalysis` | 輸出字數 | 命中 |
%[text] | --- | --- | --- |
%[text] | **`auto`（預設）** | **0** | **0 / 4** |
%[text] | `page` | 0 | 0 / 4 |
%[text] | `block` | 4 | 4 / 4 |
%[text] | `line` | 4 | 4 / 4 |
%[text] | **`word`** | **4** | **4 / 4** |
%[text] | `none` | 4 | 4 / 4 |
%[text:table]
%[text] **從 0/4 到 4/4，只差一個字串。**
%[text] 還有一個等效的修法：**把框往外擴幾個像素**。
%[text] 加 8 px 的 padding 之後連 `"auto"` 都能讀到 4/4——
%[text] 因為框不再緊貼文字，版面分析有空間運作。
%[text] `ch15_compareTextPipelines` 兩件事都做了。
%[text] > **這就是第 7 節的結論在真實流程裡的後果：**
%[text] > **`LayoutAnalysis` 描述「你餵進去的是什麼」。**
%[text] > 兩階段餵進去的是單字，就該說 `"word"`。
%%
%[text] ## 9.1 修正之後：兩階段什麼時候才值得
%[text] 參數修好之後，兩種流程在路標上的差距變得很小
%[text] （recall 91.7% vs 83.3%、precision 78.6% vs 83.3%）。
%[text] **那到底什麼時候該用兩階段？** 用背景複雜度來回答。
%[text] 造兩個只差背景的合成場景（文字內容已知，所以答案精確）：
if hasCRAFT
    sceneWords = ["ALPHA" "BRAVO" "CHARLIE" "DELTA"];
    bgNames = ["白底" "強紋理"];

    figure
    tiledlayout(1,2, TileSpacing="compact")
    fprintf("\n%-10s %16s %16s\n", "背景", "直接OCR命中", "兩階段命中");
    for b = 1:2
        scene = ch15_makeScene(sceneWords, b);
        nexttile; imshow(scene); title(bgNames(b))

        hitDirect = countHits(ocr(scene).Words, sceneWords);

        bb = detectTextCRAFT(scene);
        wTwo = strings(0);
        for k = 1:size(bb,1)
            r = bb(k,:) + [-8 -8 16 16];
            r(1) = max(1, r(1)); r(2) = max(1, r(2));
            t = ocr(imcrop(scene, r), LayoutAnalysis="word");
            wTwo = [wTwo; string(t.Words(:))];
        end
        hitTwo = countHits(wTwo, sceneWords);

        fprintf("%-10s %14d/4 %14d/4\n", bgNames(b), hitDirect, hitTwo);
    end
end
%[text] 實測：

%[text:table]
%[text] | 背景 | 直接 OCR 命中 | 兩階段命中 |
%[text] | --- | --- | --- |
%[text] | 白底 | **4 / 4** | **4 / 4** |
%[text] | 強紋理 | **1 / 4** | **4 / 4** |
%[text:table]
%[text] **背景乾淨時兩者相同；背景一複雜，直接 OCR 就崩潰到 1/4，
%[text] 而兩階段仍然 4/4。**
%[text] > **「先偵測再辨識」的價值在於**隔離背景**，不在於提升辨識精度。**
%[text] > 背景乾淨時它沒有好處，只是多花時間；
%[text] > 背景雜亂時它是唯一可行的做法。
%[text] **怎麼選：**
%[text:table]
%[text] | 情況 | 建議 |
%[text] | --- | --- |
%[text] | 掃描文件、乾淨背景 | 直接 OCR（兩階段沒有好處） |
%[text] | 場景文字、雜亂背景 | **兩階段**，ROI 用 `"word"` 或 `"line"` |
%[text] | 輸出格式已知（料號、車牌） | 直接 OCR + 正規表達式過濾 |
%[text] | 最穩健 | 兩者都跑、取聯集，再用格式規則過濾 |
%[text:table]
%%
%[text] # 10. 常見陷阱
%[text] **① 以為 1D 條碼跟 QR 一樣耐旋轉。**
%[text] QR 全角度通過，EAN-13 在 30°、45°、90° 全部失敗（第 3 節）。
%[text] **② 用「看起來對」評估 OCR。**
%[text] 用 `insertText` 合成文字就能得到精確 ground truth，
%[text] 再用 `editDistance` 算 CER（第 4 節）。
%[text] **③ 把力氣花在去雜訊。**
%[text] 雜訊 variance 加到 0.06，CER 仍然是 **0.0000**。
%[text] 而 **2 度傾斜就讓 CER 跳到 0.3667**（第 5 節）。
%[text] **④ 以為自動 deskew 一定有幫助。**
%[text] 角度估計誤差平均只有 0.78 度，但六個測試角度中只有**兩個**校正後變好——
%[text] 重新取樣的損失大於對齊的收益（第 6.1 節）。
%[text] **⑤ 在不會失敗的輸入上比較前處理方法。**
%[text] 五種方法在 CER 已經是 0 的影像上全部得到 0，什麼也分不出來（第 6 節）。
%[text] **⑥ 自己先 `imbinarize` 再送 OCR。**
%[text] 實測在四種劣化情況下**沒有一次是最好的**——`ocr` 內部的二值化更適合文字。
%[text] **⑦ 誤解 `LayoutAnalysis`。**
%[text] 它描述「你餵進去的是什麼」，不是「你想要什麼」。
%[text] 對名片用 `line` 會得到 **0 個字**（第 7 節）。
%[text] **⑧ 用 `Model="chi_tra"`。**
%[text] 那是檔名。API 名稱是 `"chinesetraditional"`（第 8 節）。
%[text] **⑨ 以為中文 OCR 開箱即用。**
%[text] 40 pt 的合成繁體中文 CER 是 **0.7778**（九個字讀對兩個）。
%[text] 中文需要更大的字級、`CharacterSet` 限制、或自訓模型。
%[text] **⑩ 繼續找 `ocrTrainer` 或 `locateText`。**
%[text] 兩者在 R2026a 都**已移除**。改用 Image Labeler + `trainOCR`（第 8.1 節）。
%[text] **⑪ 對 CRAFT 的框用預設的 `LayoutAnalysis="auto"`。**
%[text] CRAFT 的框緊貼文字，`"auto"` 會讓 OCR 誤以為那是整頁文件。
%[text] 合成場景實測：`"auto"` 得到 **0/4**、`"word"` 得到 **4/4**。
%[text] 加 padding 也能修好（第 9 節）。
%[text] **⑫ 以為「先偵測再辨識」一定比較好（或一定沒用）。**
%[text] 背景乾淨時兩者相同（4/4 vs 4/4）；
%[text] 背景強紋理時直接 OCR 崩潰到 1/4 而兩階段維持 4/4（第 9.1 節）。
%%
%[text] # 11. 本章小結
%[text] **字串沒有「差不多」**
%[text] 所以評估要用 CER，而且要有精確的 ground truth。
%[text] 合成文字是最省力的取得方式。
%[text] **OCR 的敵人排序與直覺相反**
%[text] 傾斜 ≫ 對焦 ≫ 字級 ≫ 雜訊。
%[text] 2 度傾斜的傷害比 variance 0.06 的雜訊大得多。
%[text] **前處理沒有標準流程**
%[text] 放大修好小字卻毀掉傾斜；`imbinarize` 全面無效。
%[text] 要先知道影像是**哪一種**壞。
%[text] **修正動作本身有代價**
%[text] deskew 把角度估得很準，校正後卻多半更差——
%[text] 因為多了一次重新取樣。這是本章最反直覺的一課。
%[text] **能用條碼就用條碼**
%[text] QR 有錯誤更正，任何角度都讀得到；OCR 沒有這種保護。
%[text] **兩階段的價值在隔離背景**
%[text] 乾淨背景上它沒有好處；強紋理背景上直接 OCR 只讀到 1/4，
%[text] 兩階段仍是 4/4。
%[text] 但它**必須配對的 `LayoutAnalysis`**——用預設的 `auto` 會從 4/4 掉到 0/4。
%[text] **這一章我自己改過一次結論**
%[text] 第 9 節第一版因為參數用錯，得到「兩階段 recall 只有 33%」，
%[text] 差點寫成「兩階段沒有用」。
%[text] **量到一個意外的壞結果時，先懷疑自己的設定，再懷疑工具。**
%%
%[text] # 12. 練習
%[text] 練習題在 `exercise/Ch15_Exercise.m`，解答在 `exercise/Ch15_Solution.m`。
%[text] 五題 + 一題加分題，建議 60 分鐘。
%%
%[text] # 13. 延伸閱讀與下一章
%[text] **本章函式**
%[text:table]
%[text] | 檔案 | 用途 |
%[text] | --- | --- |
%[text] | `code/ch15_barcodeRobustness.m` | 掃四種劣化，找出條碼的失敗點 |
%[text] | `code/ch15_makeTextImage.m` | 合成文字影像（提供精確 ground truth） |
%[text] | `code/ch15_makeCJKImage.m` | 合成中日韓文字，自動尋找可用字型 |
%[text] | `code/ch15_cer.m` | 字元錯誤率 |
%[text] | `code/ch15_cleanText.m` | 正規化 OCR 輸出以便比較 |
%[text] | `code/ch15_ocrDegradation.m` | 四種劣化的 CER 掃描 |
%[text] | `code/ch15_preprocessComparison.m` | 前處理比較，**強制在會失敗的輸入上測** |
%[text] | `code/ch15_deskewEvaluation.m` | 傾斜校正的效果評估 |
%[text] | `code/ch15_compareTextPipelines.m` | 直接 OCR vs 兩階段的 precision/recall |
%[text:table]
%[text] **官方文件**
%[text] `doc readBarcode`、`doc ocr`、`doc ocrText`、`doc detectTextCRAFT`、
%[text] `doc trainOCR`、`doc evaluateOCR`、`doc ocrTrainingData`
%[text] **下一章**
%[text] 第 16 章　傳統物件偵測——滑動視窗 + 手工特徵 + 分類器。
%[text] 它是理解第 19 章深度學習偵測的對照組：
%[text] **知道傳統方法卡在哪裡，才知道深度學習解決了什麼。**

% ========================================================================
function scene = ch15_makeScene(words, level)
%CH15_MAKESCENE 造背景複雜度不同的合成場景，文字內容已知。
%
%   level 1 = 白底、level 2 = 強紋理。
%   文字底下都加不透明的白框，確保**文字本身**在兩種情況下一樣清楚——
%   這樣差異就只來自背景，而不是文字被背景蓋掉。
H = 300; W = 520;
if level == 1
    bg = uint8(250*ones(H, W, 3));
else
    f = imresize(imread("fabric.png"), [H W]);
    bg = im2uint8(0.45 + 0.5*im2double(f));
end
positions = [30 40; 30 110; 30 180; 30 250];
scene = bg;
for k = 1:numel(words)
    scene = insertText(scene, positions(k,:), words(k), FontSize=34, ...
        TextColor="black", BoxColor="white", BoxOpacity=1);
end
end

% ========================================================================
function n = countHits(words, truth)
%COUNTHITS 有幾個真實字詞出現在輸出中（集合比對）。
w = upper(strtrim(string(words(:))));
w = w(strlength(w) > 0);
n = nnz(ismember(upper(truth), w));
end

% ========================================================================
%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline","rightPanelPercent":40}
%---
