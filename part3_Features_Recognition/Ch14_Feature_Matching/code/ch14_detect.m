function pts = ch14_detect(name, I, options)
%CH14_DETECT 統一八種關鍵點偵測器的呼叫介面。
%
%   PTS = CH14_DETECT(NAME, I) 用 NAME 指定的偵測器處理灰階影像 I。
%   NAME 可為 "SIFT"、"SURF"、"ORB"、"KAZE"、"BRISK"、"Harris"、
%   "FAST"、"MSER"。
%
%   名稱-值引數：
%     MaxPoints  最多回傳幾個點（用 selectStrongest 篩選），預設 Inf
%
%   為什麼要包一層
%   --------------
%   八個函式的名稱規則一致（detectXXXFeatures），但**回傳型別不同**，
%   而型別決定了後續能用哪些描述子：
%
%     SIFTPoints / SURFPoints / ORBPoints / KAZEPoints / BRISKPoints
%         -> 有尺度與方向，可用對應的不變描述子
%     cornerPoints（Harris、FAST）
%         -> **沒有尺度也沒有方向**
%     MSERRegions（MSER）
%         -> 是區域不是點
%
%   第 14 章第 6 節實測：cornerPoints 配上預設描述子只能配到 6 組，
%   改用 Method="SURF" 升到 10 組，但仍遠少於 SIFT 的 72 組。
%   **描述子需要偵測器提供尺度與方向；偵測器不給，就只能猜一個固定值。**
%
%   另見 CH14_DETECTORREPEATABILITY, CH14_MATCHANDVERIFY, EXTRACTFEATURES.

arguments
    name (1,1) string {mustBeMember(name, ["SIFT" "SURF" "ORB" "KAZE" ...
        "BRISK" "Harris" "FAST" "MSER"])}
    I {mustBeNumeric, mustBeNonempty}
    options.MaxPoints (1,1) double {mustBePositive} = Inf
end

if size(I,3) > 1
    I = im2gray(I);
end

switch name
    case "SIFT",   pts = detectSIFTFeatures(I);
    case "SURF",   pts = detectSURFFeatures(I);
    case "ORB",    pts = detectORBFeatures(I);
    case "KAZE",   pts = detectKAZEFeatures(I);
    case "BRISK",  pts = detectBRISKFeatures(I);
    case "Harris", pts = detectHarrisFeatures(I);
    case "FAST",   pts = detectFASTFeatures(I);
    case "MSER",   pts = detectMSERFeatures(I);
end

% MSERRegions 不支援 selectStrongest（它是區域不是點，沒有強度可排序）
if isfinite(options.MaxPoints) && name ~= "MSER"
    n = min(options.MaxPoints, pts.Count);
    pts = selectStrongest(pts, n);
end
end
