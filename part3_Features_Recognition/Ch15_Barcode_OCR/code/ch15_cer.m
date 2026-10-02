function e = ch15_cer(hypothesis, reference)
%CH15_CER 字元錯誤率（Character Error Rate）。
%
%   E = CH15_CER(HYPOTHESIS, REFERENCE) 回傳
%   編輯距離(HYPOTHESIS, REFERENCE) / strlength(REFERENCE)。
%
%   0 代表完全正確。**注意 E 可以大於 1**——當輸出比參考字串長時，
%   編輯距離會超過參考長度。第 15 章第 6 節實測到 1.2333
%   （放大 2 倍讓傾斜的文字產生大量多餘字元）。
%
%   為什麼用 CER 而不是「完全比對」
%   ------------------------------
%   完全比對只給 0 或 1，看不出「錯一個字元」與「全錯」的差別。
%   掃描參數時整條曲線會是階梯狀，無法判斷趨勢或找出失效點。
%
%   CER 讓你能畫出連續的劣化曲線，例如第 15 章第 5 節的旋轉掃描：
%
%     角度    CER
%      0°   0.0000
%      1°   0.0667
%      2°   0.2667
%     10°   0.3333
%     20°   1.0000
%
%   看得出「2 度就開始嚴重惡化」——這是完全比對給不出的資訊。
%
%   怎麼取得 REFERENCE
%   ------------------
%   OCR 評估最大的成本是標註。最省力的做法是**自己合成文字影像**：
%   用 insertText 把已知字串畫上去，那個字串就是 ground truth。
%   見 CH15_MAKETEXTIMAGE。
%
%   真實影像則需要人工標註，或用 Image Labeler + ocrTrainingData
%   （第 8.1 節）。R2023b 起的 evaluateOCR 會直接回報 CER 與 WER。
%
%   範例：
%     gt  = "ABCDEFG 0123456789";
%     img = ch15_makeTextImage(gt, 28);
%     got = ch15_cleanText(ocr(img).Text);
%     fprintf("CER = %.4f\n", ch15_cer(got, gt));
%
%   另見 EDITDISTANCE, CH15_CLEANTEXT, CH15_MAKETEXTIMAGE, EVALUATEOCR.

arguments
    hypothesis (1,1) string
    reference  (1,1) string
end

refLen = strlength(reference);
if refLen == 0
    error("ch15_cer:emptyReference", ...
        "參考字串是空的，無法計算錯誤率（分母為零）。");
end

e = editDistance(hypothesis, reference) / refLen;
end
