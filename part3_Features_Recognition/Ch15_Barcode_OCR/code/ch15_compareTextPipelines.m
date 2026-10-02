function cmpTbl = ch15_compareTextPipelines(img, bboxes, options)
%CH15_COMPARETEXTPIPELINES 比較「直接 OCR」與「CRAFT 兩階段」的 precision/recall。
%
%   CMPTBL = CH15_COMPARETEXTPIPELINES(IMG, BBOXES) 對同一張場景文字影像，
%   分別用直接 OCR 與逐區域 OCR，回傳 precision／recall 比較表。
%   為了讓一個關鍵陷阱可見，兩階段會**同時**用正確與錯誤的
%   LayoutAnalysis 各跑一次。
%
%   名稱-值引數：
%     TruthWords  人工標註的真實字詞，預設是 handicapSign.jpg 的 12 個字
%     RoiLayout   逐區域 OCR 用的 LayoutAnalysis，預設 "word"
%     Padding     ROI 往外擴幾個像素，預設 8
%
%   **最重要的一件事：ROI 不能用 LayoutAnalysis="auto"**
%   ------------------------------------------------------
%   這是寫這一章時真實踩到的坑，而且它一度讓我得出**錯誤的結論**。
%
%   CRAFT 回傳的框是**緊貼文字**的。對這種框用預設的 "auto"（或 "page"），
%   OCR 會以為那是一整頁文件、試圖做版面分析，結果**什麼都讀不到**。
%
%   合成場景（四個單字、白底）實測：
%
%     ROI 的 LayoutAnalysis    輸出字數   命中
%     auto（預設）                  0     0/4
%     page                         0     0/4
%     block                        4     4/4
%     line                         4     4/4
%     word                         4     4/4
%     none                         4     4/4
%
%   **只要把 "auto" 換成 "word"，命中率就從 0/4 變成 4/4。**
%
%   另一個等效的修法是**把框往外擴幾個像素**：加 8 px 的 padding 之後，
%   連 "auto" 都能讀到 4/4——因為框不再緊貼文字，版面分析有空間運作。
%   本函式兩件事都做。
%
%   這正是第 15 章第 7 節的結論：
%   **LayoutAnalysis 描述的是「你餵進去的是什麼」，不是「你想要什麼」。**
%   兩階段流程餵進去的是單字，就該說 "word"。
%
%   > **我第一次做這個比較時用了預設值，得到「兩階段 recall 只有 33%」
%   > 的結論，並且差點把它寫進教材。那個數字不是 CRAFT 的問題，
%   > 是我自己的參數錯誤。**
%
%   背景越複雜，兩階段越有價值
%   --------------------------
%   修正參數之後，兩種流程的優劣與**背景複雜度**直接相關（合成場景實測）：
%
%     背景          直接 OCR 命中   兩階段命中
%     白底                4/4          4/4
%     強紋理              1/4          4/4
%
%   在乾淨背景上兩者相同；背景一複雜，直接 OCR 就崩潰，
%   而兩階段因為先把文字框出來，**不受背景干擾**。
%
%   > **「先偵測再辨識」的價值在於隔離背景，不在於提升辨識精度。**
%   > 背景乾淨時它沒有好處，只是多花時間。
%
%   關於評估方式的限制
%   ------------------
%   本函式用**字詞集合**比對（忽略順序與重複），因為場景文字的
%   閱讀順序本來就不唯一。若你的應用在意順序（例如整段文章），
%   應改用 CER 而非集合比對。
%
%   範例：
%     sign = imread("handicapSign.jpg");
%     bb   = detectTextCRAFT(sign);
%     disp(ch15_compareTextPipelines(sign, bb))
%
%   另見 DETECTTEXTCRAFT, OCR, CH15_CER.

arguments
    img    {mustBeNumeric, mustBeNonempty}
    bboxes {mustBeNumeric}
    options.TruthWords (1,:) string = ["PARKING" "SPECIAL" "PLATE" ...
        "REQUIRED" "UNAUTHORIZED" "VEHICLES" "MAY" "BE" "TOWED" ...
        "AT" "OWNERS" "EXPENSE"]
    options.RoiLayout (1,1) string = "word"
    options.Padding   (1,1) double {mustBeNonnegative} = 8
end

truth = upper(options.TruthWords);

% --- 流程 A：直接 OCR -------------------------------------------------
wordsDirect = normalizeWords(ocr(img).Words);

% --- 流程 B / C：兩階段（正確與錯誤的 LayoutAnalysis）----------------
wordsGood = strings(0);
wordsAuto = strings(0);

if isempty(bboxes) || size(bboxes,1) == 0
    warning("ch15_compareTextPipelines:noRegions", ...
        "detectTextCRAFT 沒有找到任何文字區域，兩階段流程無法進行。");
else
    for k = 1:size(bboxes,1)
        crop = cropWithPadding(img, bboxes(k,:), options.Padding);
        wordsGood = [wordsGood; ...
            normalizeWords(ocr(crop, LayoutAnalysis=options.RoiLayout).Words)];
        % 刻意用預設值，讓陷阱可見
        wordsAuto = [wordsAuto; ...
            normalizeWords(ocr(crop, LayoutAnalysis="auto").Words)];
    end
end

% --- 指標 -------------------------------------------------------------
[recA, precA, hitA] = prf(wordsDirect, truth);
[recB, precB, hitB] = prf(wordsGood,  truth);
[recC, precC, hitC] = prf(wordsAuto,  truth);

cmpTbl = table( ...
    ["DirectOCR"; "TwoStage_" + options.RoiLayout; "TwoStage_auto"], ...
    [numel(wordsDirect); numel(wordsGood); numel(wordsAuto)], ...
    [hitA; hitB; hitC], ...
    [recA; recB; recC], ...
    [precA; precB; precC], ...
    VariableNames=["Pipeline" "WordsOut" "Hits" "RecallPct" "PrecisionPct"]);

% --- 把陷阱講出來 -----------------------------------------------------
if recB > recC
    fprintf("ROI 的 LayoutAnalysis 影響極大：\n");
    fprintf("  用 ""%s"" -> recall %.1f%%\n", options.RoiLayout, recB);
    fprintf("  用 ""auto"" -> recall %.1f%%\n", recC);
    fprintf("**CRAFT 的框緊貼文字，用 auto 會讓 OCR 誤以為那是整頁文件。**\n");
end
end

% ========================================================================
function crop = cropWithPadding(img, bbox, pad)
%CROPWITHPADDING 裁切並往外擴 PAD 像素。
%
%   為什麼要擴：緊貼文字的框會讓版面分析失效。加一點邊界之後，
%   連 LayoutAnalysis="auto" 都能正常運作（實測從 0/4 變成 4/4）。
r = bbox + [-pad, -pad, 2*pad, 2*pad];
r(1) = max(1, r(1));
r(2) = max(1, r(2));
crop = imcrop(img, r);
end

% ========================================================================
function w = normalizeWords(words)
%NORMALIZEWORDS 轉大寫、去空白、丟掉空字串與純標點。
w = upper(strtrim(string(words(:))));
w = w(strlength(w) > 0);
if isempty(w)
    return
end
% 只保留含至少一個字母或數字的項目，避免 "=" "{|" 這類被當成字詞。
% 注意 regexp 對 string 陣列用 "once" 會回傳 double 而非 cell，
% 所以先轉成 cellstr 再判斷。
keep = ~cellfun(@isempty, regexp(cellstr(w), "[A-Z0-9]", "once"));
w = w(keep);
end

% ========================================================================
function [recallPct, precisionPct, hits] = prf(found, truth)
%PRF 以**集合**比對計算 recall 與 precision。
if isempty(found)
    recallPct = 0; precisionPct = 0; hits = 0;
    return
end
hits = nnz(ismember(truth, found));
recallPct    = 100 * hits / numel(truth);
precisionPct = 100 * nnz(ismember(found, truth)) / numel(found);
end
