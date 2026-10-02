function [medianLength, lines, fingerprint] = ch10_wormLengthWithFingerprint(BW, options)
%CH10_WORMLENGTHWITHFINGERPRINT 量測線狀物件長度，並回傳校正指紋。
%
%   [MEDIANLENGTH, LINES, FINGERPRINT] = CH10_WORMLENGTHWITHFINGERPRINT(BW)
%   與 ch10_wormLength 的計算完全相同，但**額外回傳一個字串指紋**，
%   記錄產生這個數值的所有關鍵設定。
%
%   為什麼需要指紋
%   --------------
%   第 10 章第 8.2 節示範了一個真實的事故：原版教材把判斷門檻 58 寫死在
%   程式裡，後來把 `bwmorph(...,"skel",Inf)` 更新成 `bwskel`，
%   同一張影像的中位長度從 46.6 變成 58.7——**跨過門檻，分類結論反轉**。
%
%   問題不在於哪個骨架化方法比較好，而在於**那個門檻 58 從來就不是一個
%   物理常數**。它是「舊版骨架化 ＋ 這組霍夫參數」整條管線的產物。
%   管線裡任何一環變了，門檻就該重新校正——但程式碼裡沒有任何東西
%   記錄這件事，所以沒有人會注意到。
%
%   指紋就是把這個資訊**變成資料**，讓它能跟著門檻一起流動，
%   並且在使用時可以被機器檢查。
%
%   指紋包含什麼
%   ------------
%   所有會影響輸出數值的設定：骨架化方法、霍夫峰值數、鄰域大小、峰值門檻。
%   不包含與數值無關的東西（例如是否繪圖）。
%
%   範例：
%     bw = logical(imread("wormsBW1.png"));
%     [len, ~, fp] = ch10_wormLengthWithFingerprint(bw);
%
%     calibration = struct(Threshold=65.1, Fingerprint=fp, ...
%                          Source="由 wormsBW1/2 於 2026-09-16 校正");
%
%     % 之後使用時
%     ch10_classifyWorm(len, calibration, fp);
%
%   另見 CH10_WORMLENGTH, CH10_CLASSIFYWORM.

arguments
    BW {mustBeA(BW, ["logical" "numeric"])}
    options.SkeletonMethod (1,1) string ...
        {mustBeMember(options.SkeletonMethod, ["bwskel" "bwmorph"])} = "bwskel"
    options.NumPeaks      (1,1) double {mustBePositive, mustBeInteger} = 30
    options.NHoodSize     (1,2) double {mustBePositive}                = [55 11]
    options.PeakThreshold (1,1) double {mustBeInRange(options.PeakThreshold, 0, 1)} = 0.4
end

[medianLength, lines] = ch10_wormLength(BW, ...
    SkeletonMethod = options.SkeletonMethod, ...
    NumPeaks       = options.NumPeaks, ...
    NHoodSize      = options.NHoodSize, ...
    PeakThreshold  = options.PeakThreshold);

% 指紋只納入**會改變輸出數值**的設定
fingerprint = sprintf("skel=%s|peaks=%d|nhood=%dx%d|thresh=%.2f", ...
    options.SkeletonMethod, options.NumPeaks, ...
    options.NHoodSize(1), options.NHoodSize(2), options.PeakThreshold);
end
