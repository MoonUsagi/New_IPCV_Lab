function [A, usedFont] = ch15_makeCJKImage(txt, fontSize, options)
%CH15_MAKECJKIMAGE 合成中日韓文字影像，自動尋找系統上可用的字型。
%
%   [A, USEDFONT] = CH15_MAKECJKIMAGE(TXT, FONTSIZE) 依序嘗試常見的
%   中日韓字型，回傳合成影像與實際用到的字型名稱。
%   全部失敗時 A 為空，USEDFONT 為 ""。
%
%   名稱-值引數：
%     Fonts   要嘗試的字型清單，預設涵蓋常見的繁中／簡中／日韓字型
%
%   為什麼需要這支函式
%   ------------------
%   **R2026a 的 insertText 預設字型是 Roboto-Regular，不含中日韓字元。**
%   直接傳中文會得到警告：
%
%     The default font, Roboto-Regular, does not contain one or more
%     characters that you specified as input.
%
%   而且畫出來是缺字方塊，OCR 自然讀不出東西。必須用 Font 參數
%   指定一個支援 CJK 的字型——但可用的字型**因作業系統而異**，
%   所以這裡用 try/catch 逐一嘗試。
%
%   中文 OCR 的實測表現（第 15 章第 8 節）
%   --------------------------------------
%   用 MingLiU 40 pt 合成「影像處理與電腦視覺」九個字：
%
%     Model                  CER      辨識結果
%     english              1.0000     AGEN
%     chinesetraditional   0.7778     影像 處 惠
%     chinesesimplified    0.7778     影像 处 理
%
%   **九個字只讀對兩個。** 原因：
%     · 中文字元集有數千個，混淆機會比英文多兩個數量級
%     · 筆畫密度高，40 pt 對「覺」這種 20 畫的字遠遠不夠
%     · Tesseract 的中文模型訓練於掃描印刷文件，與合成點陣字分布不同
%
%   所以中文 OCR 需要：**更大的字級**（英文的 2–3 倍）、
%   用 CharacterSet 限制字元集、或自訓模型。
%
%   注意 Model 的名稱是 "chinesetraditional"，不是 "chi_tra"——
%   後者是 traineddata 的**檔名**，傳進去會得到
%   Invalid language character vector。
%
%   範例：
%     [img, f] = ch15_makeCJKImage("影像處理", 60);
%     if ~isempty(img)
%         t = ocr(img, Model="chinesetraditional");
%         fprintf("字型 %s：[%s]\n", f, ch15_cleanText(t.Text));
%     end
%
%   另見 CH15_MAKETEXTIMAGE, INSERTTEXT, OCR, LISTTRUETYPEFONTS.

arguments
    txt      (1,1) string {mustBeNonzeroLengthText}
    fontSize (1,1) double {mustBePositive} = 40
    options.Fonts (1,:) string = ["MingLiU" "PMingLiU" "Microsoft JhengHei" ...
        "Microsoft YaHei" "SimSun" "SimHei" "NSimSun" "MS Gothic" "Malgun Gothic"]
end

A = [];
usedFont = "";

% 中文字是方的，寬高比接近 1，畫布要比英文寬
h = round(fontSize * 2.2);
w = round(fontSize * strlength(txt) * 1.15) + 40;
canvas = uint8(255 * ones(h, w, 3));

for f = options.Fonts
    try
        A = insertText(canvas, [15 round(fontSize*0.45)], txt, ...
            Font=f, FontSize=fontSize, TextColor="black", BoxOpacity=0);
        usedFont = f;
        return
    catch
        % 這個字型不存在或不支援，換下一個
    end
end

warning("ch15_makeCJKImage:noCJKFont", ...
    "嘗試了 %d 種字型都無法繪製中日韓文字。" + ...
    "insertText 的預設字型 Roboto-Regular 不含 CJK 字元，" + ...
    "而系統上找不到清單中的任何一種替代字型。" + ...
    "可用 listTrueTypeFonts 查看系統有哪些字型，再用 Fonts 引數指定。", ...
    numel(options.Fonts));
end
