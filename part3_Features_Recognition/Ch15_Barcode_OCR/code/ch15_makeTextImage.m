function A = ch15_makeTextImage(txt, fontSize, options)
%CH15_MAKETEXTIMAGE 合成文字影像，提供**精確的** ground truth。
%
%   A = CH15_MAKETEXTIMAGE(TXT, FONTSIZE) 產生一張白底黑字的影像，
%   內容就是 TXT。因為字串是你給的，它就是完美的 ground truth。
%
%   名稱-值引數：
%     Margin      文字距離左上角的邊距，預設 10
%     TextColor   文字顏色，預設 "black"
%     BackColor   背景灰階值 0-255，預設 255（白）
%
%   為什麼這是評估 OCR 最省力的方法
%   ------------------------------
%   OCR 評估最大的成本是標註。合成文字把這個成本降到零：
%   你**知道**影像裡寫什麼，因為是你寫上去的。
%
%   有了精確的 ground truth，就能做第 15 章第 5 節那種掃描：
%   對同一段文字施加不同強度的劣化，畫出 CER 曲線，找出失效點。
%   那些數字用真實影像要標註幾百張才做得出來。
%
%   **它的限制也要說清楚**
%   ----------------------
%   合成文字**不等於**真實掃描或拍攝的文字：
%     · 沒有紙張紋理、墨水暈染、壓縮雜訊
%     · 字型是螢幕字型，不是印刷字型
%     · 沒有光照不均
%
%   所以用它量到的絕對 CER 會**比真實情況樂觀**。
%   它的價值在**比較**（哪種劣化更致命、哪種前處理有效），
%   不在預測真實世界的絕對準確率。
%
%   這與第 13 章合成訓練資料的教訓一致：
%   **合成資料的分布不是真實分布**，用途要限定在它成立的範圍內。
%
%   注意 R2026a 的預設字型
%   ----------------------
%   insertText 的預設字型是 Roboto-Regular，**不含中日韓字元**。
%   要合成中文請用 CH15_MAKECJKIMAGE，它會自動尋找可用的字型。
%
%   範例：
%     gt  = "ABCDEFG 0123456789 Hello World";
%     img = ch15_makeTextImage(gt, 28);
%     fprintf("CER = %.4f\n", ch15_cer(ch15_cleanText(ocr(img).Text), gt));
%
%   另見 INSERTTEXT, CH15_MAKECJKIMAGE, CH15_CER, OCR.

arguments
    txt      (1,1) string {mustBeNonzeroLengthText}
    fontSize (1,1) double {mustBePositive} = 28
    options.Margin    (1,1) double {mustBeNonnegative} = 10
    options.TextColor (1,1) string = "black"
    options.BackColor (1,1) double {mustBeInRange(options.BackColor,0,255)} = 255
end

% 畫布要夠大才不會截字。0.75 是英數字的粗略平均寬高比。
h = round(fontSize * 3);
w = round(fontSize * strlength(txt) * 0.75) + 2*options.Margin;
canvas = uint8(options.BackColor * ones(h, w, 3));

A = insertText(canvas, [options.Margin fontSize], txt, ...
    FontSize=fontSize, TextColor=options.TextColor, BoxOpacity=0);
end
