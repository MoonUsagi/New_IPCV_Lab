function result = ch23_ballSegmentFrame(frame, options)
%CH23_BALLSEGMENTFRAME 在單張影格中找出綠色的球。
%
%   RESULT = CH23_BALLSEGMENTFRAME(FRAME) 在一張 RGB 影格中尋找綠色球體，
%   回傳一個 struct，欄位為：
%     Found     logical，這張影格是否找到球
%     Centroid  1x2 質心 [x y]，找不到時為 [NaN NaN]
%     Area      區塊面積（像素），找不到時為 NaN
%     BBox      1x4 外接矩形，找不到時為 NaN(1,4)
%     Mask      logical 遮罩，找不到時為全 false
%
%   **這支函式只處理一張影格，而且只做一件事。**
%   它不讀檔、不顯示、不寫檔、不累積結果——那些是呼叫者的責任。
%   第 4 節說明為什麼這個切法是整章的關鍵。
%
%   名稱-值引數：
%     Threshold  綠色通道領先幅度的門檻，預設 15
%                （G - max(R,B) > Threshold 才算綠色）
%     MinArea    最小區塊面積，預設 40 像素
%     FillHoles  是否填補孔洞，預設 true
%
%   **回傳 Found=false 不是錯誤。** singleball.mp4 有 45 幀，
%   球只在其中 23 幀看得見（其餘被紙箱遮住或還沒進畫面）。
%   函式必須能誠實說「這一幀沒有」，呼叫者才有機會正確處理。
%
%   範例：
%     v = VideoReader("singleball.mp4");
%     r = ch23_ballSegmentFrame(read(v, 20));
%     fprintf("Found=%d  質心=(%.1f, %.1f)\n", r.Found, r.Centroid);
%
%   另見 CH23_BALLSEGMENTVIDEO, CH23_PIPELINEPROFILE.

arguments
    frame                    uint8
    options.Threshold (1,1) double {mustBePositive} = 15
    options.MinArea   (1,1) double {mustBePositive} = 40
    options.FillHoles (1,1) logical = true
end

if size(frame,3) ~= 3
    error("ipcv:ch23:notRGB", "輸入必須是 RGB 影格（M x N x 3）。");
end

% 綠色偵測：看綠通道比另外兩個通道**領先多少**，而不是看綠通道的絕對值。
% 絕對值會被整體亮度牽著走；領先幅度對照明變化穩健得多。
R = double(frame(:,:,1));
G = double(frame(:,:,2));
B = double(frame(:,:,3));
mask = (G - max(R,B)) > options.Threshold;

if options.FillHoles
    mask = imfill(mask, "holes");
end
mask = bwareaopen(mask, options.MinArea);

stats = regionprops(mask, "Area", "Centroid", "BoundingBox");

result = struct( ...
    Found    = false, ...
    Centroid = [NaN NaN], ...
    Area     = NaN, ...
    BBox     = NaN(1,4), ...
    Mask     = false(size(mask)));

if isempty(stats)
    return
end

% 只留最大的區塊。這個假設（畫面上最多一顆球）要寫在文件裡，
% 因為它在多球場景會安靜地給出錯誤答案——第 24 章處理多目標。
[~, idx] = max([stats.Area]);

result.Found    = true;
result.Centroid = stats(idx).Centroid;
result.Area     = stats(idx).Area;
result.BBox     = stats(idx).BoundingBox;
result.Mask     = bwareafilt(mask, 1);
end
