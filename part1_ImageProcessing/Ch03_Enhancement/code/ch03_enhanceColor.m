function [out, diagnostics] = ch03_enhanceColor(RGB, method, options)
%CH03_ENHANCECOLOR 增強彩色影像，把色相偏移壓到最低。
%
%   OUT = CH03_ENHANCECOLOR(RGB) 用預設的對比拉伸增強影像。
%
%   OUT = CH03_ENHANCECOLOR(RGB, METHOD) 指定增強方法：
%     "stretch"  對比拉伸（預設，最溫和）
%     "histeq"   全域直方圖等化
%     "clahe"    局部等化（CLAHE），照明不均時使用
%
%   [OUT, DIAGNOSTICS] = CH03_ENHANCECOLOR(___) 另外回傳診斷 struct，
%   含平均色相偏移（度）、對比變化與使用的方法，方便驗證顏色沒有跑掉。
%
%   名稱-值引數：
%     ClipLimit   CLAHE 的對比限制，只在 method="clahe" 時有效。預設 0.01
%     ColorSpace  "lab"（預設）或 "hsv"，決定在哪個空間分離亮度
%
%   為什麼不能逐通道處理
%   --------------------
%   顏色是由 R、G、B 三個通道的**相對比例**決定的。對每個通道各自做點運算
%   （histeq、gamma、拉伸都算）會改變這個比例，因此一定會改變色相——
%   即使你三個通道用的是「同一種」處理也一樣，因為每個通道的直方圖不同，
%   等化後的映射曲線就不同。
%
%   正確做法是換到把亮度與顏色分離的空間（L*a*b* 的 L，或 HSV 的 V），
%   只處理亮度通道，色度通道原封不動。
%
%   兩個色彩空間的取捨（第 03 章對 coloredChips.png 的實測）
%   -------------------------------------------------------
%     做法                    平均色相偏移    說明
%     逐通道 histeq              9.9 度      錯誤做法，當對照組
%     lab  + stretch             1.9 度
%     lab  + clahe               4.2 度
%     lab  + histeq             12.2 度      比錯誤做法還糟，別用
%     hsv  + 任何方法            0.0 度      數學上色相完全不變
%
%   為什麼 lab 還是會偏：把 L 改掉之後，(L,a,b) 的組合可能落在 sRGB 色域外，
%   lab2rgb 會把超出的通道值裁切回 [0,1]，裁切就改變了通道比例，因而改變色相。
%   實測超出色域的通道值佔比：stretch 5.9%、clahe 7.5%、histeq 13.2%——
%   越激進的方法推出去越多，色相偏移也越大。
%
%   HSV 的 V 是 max(R,G,B)，調整它等於把三個通道同比例縮放，H 與 S 依定義
%   不變（實測誤差 1.8e-15，純浮點誤差）。
%
%   那為什麼預設不是 hsv？因為 L*a*b* 的 L 是**感知均勻**的亮度，
%   在它上面做對比增強，視覺效果比在 V 上做自然得多。多數情況下
%   4 度以內的色相偏移看不出來，換得較好的視覺品質是划算的。
%   但如果你的下游要做**顏色分割或色差量測**，請改用 ColorSpace="hsv"。
%
%   範例：
%     RGB = imread("coloredChips.png");
%
%     [J, d] = ch03_enhanceColor(RGB, "clahe");
%     fprintf("色相偏移 %.1f 度\n", d.MeanHueShiftDegrees);
%     montage({RGB, J})
%
%     % 比較三種方法
%     methods = ["stretch" "histeq" "clahe"];
%     for m = methods
%         [~, d] = ch03_enhanceColor(RGB, m);
%         fprintf("%-8s 色相偏移 %.1f 度\n", m, d.MeanHueShiftDegrees);
%     end
%
%   另見 IMADJUST, HISTEQ, ADAPTHISTEQ, RGB2LAB.

arguments
    RGB            {mustBeNumeric, mustBeNonempty}
    method  (1,1) string {mustBeMember(method, ["stretch" "histeq" "clahe"])} = "stretch"
    options.ClipLimit  (1,1) double {mustBeInRange(options.ClipLimit, 0, 1)}   = 0.01
    options.ColorSpace (1,1) string {mustBeMember(options.ColorSpace, ["lab" "hsv"])} = "lab"
end

if size(RGB, 3) ~= 3
    error("ch03_enhanceColor:notRGB", ...
        "輸入必須是三通道 RGB 影像，但收到 %d 個通道。若是灰階影像，直接用 imadjust 等函式即可。", ...
        size(RGB, 3));
end

% --- 分離亮度通道 ------------------------------------------------------
switch options.ColorSpace
    case "lab"
        conv    = rgb2lab(RGB);
        lum     = conv(:,:,1) / 100;        % L 的範圍是 0–100，正規化到 0–1
        restore = @(L) applyLab(conv, L);
    case "hsv"
        conv    = rgb2hsv(RGB);
        lum     = conv(:,:,3);              % V 已經是 0–1
        restore = @(L) applyHsv(conv, L);
end

if options.ColorSpace == "lab" && method == "histeq"
    % 注意：用 + 串接字串。方括號搭配雙引號會得到 string 陣列而非單一字串，
    % warning 只接受純量字串，會直接報錯。
    warning("ch03_enhanceColor:worstCombo", ...
        "lab + histeq 是最糟的組合：histeq 會把大量像素推出 sRGB 色域，" + ...
        "裁切後的色相偏移比逐通道處理還大。" + ...
        "請改用 method=""clahe"" 或 ColorSpace=""hsv""。");
end

% --- 只對亮度通道做增強 ------------------------------------------------
switch method
    case "stretch"
        lumOut = imadjust(lum, stretchlim(lum), []);
    case "histeq"
        lumOut = histeq(lum);
    case "clahe"
        lumOut = adapthisteq(lum, ClipLimit=options.ClipLimit);
end

out = restore(lumOut);

% --- 診斷：量化顏色跑掉了多少 -----------------------------------------
if nargout > 1
    hsv0 = rgb2hsv(RGB);
    hsv1 = rgb2hsv(out);

    sel = hsv0(:,:,2) > 0.45;               % 只看顏色明確的像素
    if ~any(sel, "all")
        sel = true(size(hsv0,1), size(hsv0,2));
    end

    % 色相是環狀的：差值要繞回 [-0.5, 0.5]
    d = mod(hsv1(:,:,1) - hsv0(:,:,1) + 0.5, 1) - 0.5;

    % 有多少通道值被色域裁切？這是 lab 路線色相偏移的根源
    if options.ColorSpace == "lab"
        labOut = conv;
        labOut(:,:,1) = lumOut * 100;
        rgbUnclipped  = lab2rgb(labOut);                 % double，未裁切
        outOfGamut    = mean(rgbUnclipped < 0 | rgbUnclipped > 1, "all");
    else
        outOfGamut = 0;
    end

    diagnostics = struct( ...
        "Method",              method, ...
        "ColorSpace",          options.ColorSpace, ...
        "MeanHueShiftDegrees", 360 * mean(abs(d(sel))), ...
        "MaxHueShiftDegrees",  360 * max(abs(d(sel))), ...
        "OutOfGamutFraction",  outOfGamut, ...
        "ContrastBefore",      std(double(im2gray(RGB)), 0, "all"), ...
        "ContrastAfter",       std(double(im2gray(out)),  0, "all"));
end
end

% ========================================================================
function out = applyLab(labImage, newL)
labImage(:,:,1) = newL * 100;
out = lab2rgb(labImage, OutputType="uint8");
end

function out = applyHsv(hsvImage, newV)
hsvImage(:,:,3) = newV;
out = im2uint8(hsv2rgb(hsvImage));
end
