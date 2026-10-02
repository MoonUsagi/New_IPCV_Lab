function [ps, ss] = ch13_holeMetrics(ref, test, mask)
%CH13_HOLEMETRICS 只在遮罩範圍內計算 PSNR 與 SSIM。
%
%   [PS, SS] = CH13_HOLEMETRICS(REF, TEST, MASK) 取 MASK 的外接矩形，
%   在該範圍內比較 TEST 與 REF。
%
%   為什麼不能用整張影像
%   --------------------
%   修復只改變遮罩內的像素，遮罩外完全相同。把未修改的區域一起納入統計，
%   會把誤差**稀釋**到看不出來。
%
%   第 13 章第 3.1 節實測（洞占影像 4.12%，inpaintExemplar）：
%
%     整張影像   PSNR 26.832 dB、SSIM 0.9716   <- 看起來幾乎完美
%     只看洞內   PSNR 12.981 dB、SSIM 0.3285   <- 真實表現
%
%   SSIM 從 0.9716 掉到 0.3285。**統計範圍決定結論。**
%
%   這與第 11 章「碰邊物件要排除」、第 12 章練習 1「局部破壞被平均稀釋」
%   是同一個原則。
%
%   注意：這裡取的是**外接矩形**而不是遮罩本身的像素。
%   SSIM 需要空間鄰域才能計算，無法對散亂的像素集合求值。
%   外接矩形會包含一些未修改的像素，所以這個數字仍然**略微樂觀**——
%   但比整張影像誠實得多。
%
%   範例：
%     I  = imread("peppers.png");
%     m  = false(size(I,1), size(I,2)); m(120:209, 200:289) = true;
%     J  = inpaintCoherent(I, m);
%     [ps, ss] = ch13_holeMetrics(I, J, m);
%     fprintf("洞內 PSNR %.3f、SSIM %.4f\n", ps, ss);
%
%   另見 CH13_GRADENERGY, CH13_INPAINTCOMPARE, PSNR, SSIM.

arguments
    ref  {mustBeNumeric, mustBeNonempty}
    test {mustBeNumeric, mustBeNonempty}
    mask {mustBeA(mask, ["logical" "numeric"])}
end

if ~islogical(mask), mask = logical(mask); end
if ~any(mask(:))
    error("ch13_holeMetrics:emptyMask", "遮罩是空的，沒有範圍可以評估。");
end
if ~isequal(size(ref), size(test))
    error("ch13_holeMetrics:sizeMismatch", ...
        "REF 尺寸 %s 與 TEST 尺寸 %s 不同。", ...
        mat2str(size(ref)), mat2str(size(test)));
end

[r, c] = find(mask);
rr = min(r):max(r);
cc = min(c):max(c);

A = im2double(ref(rr, cc, :));
B = im2double(test(rr, cc, :));

ps = psnr(B, A);

if size(A,3) > 1
    ss = ssim(im2gray(B), im2gray(A));
else
    ss = ssim(B, A);
end
end
