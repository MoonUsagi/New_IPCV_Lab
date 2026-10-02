function repeatTbl = ch14_detectorRepeatability(I, options)
%CH14_DETECTORREPEATABILITY 用已知變換量測偵測器的重複性。
%
%   REPEATTBL = CH14_DETECTORREPEATABILITY(I) 對多個偵測器、多種已知
%   變換，計算「原圖的關鍵點投影過去之後，變換後影像是否也偵測到」
%   的百分比。
%
%   名稱-值引數：
%     Detectors   要測的偵測器，預設七種（MSER 是區域，不適用）
%     Tolerance   判定為「同一個點」的距離容忍（像素），預設 3
%
%   為什麼這樣量才對
%   ----------------
%   重複性的定義是「同一個**物理位置**在變換後還能被偵測到」。
%   要量它，必須知道正確答案——所以**自己套一個已知的 tform**。
%
%   兩個容易做錯的地方：
%
%   **① 分母只能算「投影後還在畫面內」的點。**
%   旋轉會把邊角的點轉出畫面，那不是偵測器的失敗。
%   不排除的話，旋轉角度越大分數自動越低，量到的是畫面裁切不是重複性。
%
%   **② 要用 tform 投影，不能只比座標。**
%   變換後的點座標當然和原圖不同；必須先把原圖的點用同一個 tform
%   投影到變換後的座標系，才能比較。
%
%   實測結果與兩個反直覺的發現（第 14 章第 3 節，cameraman.tif）
%   -----------------------------------------------------------
%     偵測器   旋轉15   旋轉45   縮放0.7  縮放1.5  旋轉30+0.8
%     SIFT     74.5%   85.6%    49.8%   71.7%    58.5%
%     SURF     67.7%   51.4%    67.8%   47.6%    52.2%
%     ORB      87.6%   41.1%    94.6%   57.2%    69.3%
%     KAZE     85.4%   80.1%    76.1%   79.3%    75.7%
%     BRISK    85.8%   88.3%    91.8%   83.6%    91.6%
%     Harris   81.2%   75.3%    67.9%   82.0%    74.1%
%     FAST     83.9%   88.5%    85.7%   76.0%    87.5%
%
%   **① SIFT 在縮放 0.7 只有 49.8%**，是那一欄最差的——
%   而它的名字就叫「尺度不變」。原因：縮小影像讓細尺度的特徵
%   **物理上消失**。尺度不變性保證「同一特徵在不同尺度能被認出」，
%   **不保證「特徵在任何尺度下都還存在」**。
%
%   **② ORB 在旋轉 45° 掉到 41.1%**，45° 是它最糟的角度——
%   FAST 基礎偵測器用固定的像素環樣板，45° 時與像素格點的對齊最差。
%
%   **這個函式量不到的東西（很重要）**
%   ----------------------------------
%   它只量「位置有沒有被再次偵測到」，**完全沒有量能不能配對**。
%   第 14 章第 5 節實測：BRISK 的重複性最高（91.6%）但只配到 7 組，
%   SIFT 重複性只有 58.5% 卻配到 72 組且 100% 內點。
%
%   > **只看這張表會選錯偵測器。** 必須搭配 CH14_MATCHANDVERIFY。
%
%   範例：
%     I = im2gray(imread("cameraman.tif"));
%     disp(ch14_detectorRepeatability(I))
%
%   另見 CH14_MATCHANDVERIFY, CH14_DETECT.

arguments
    I {mustBeNumeric, mustBeNonempty}
    options.Detectors (1,:) string = ["SIFT" "SURF" "ORB" "KAZE" ...
                                      "BRISK" "Harris" "FAST"]
    options.Tolerance (1,1) double {mustBePositive} = 3
end

if size(I,3) > 1, I = im2gray(I); end
R = imref2d(size(I));

condNames = ["Rot15" "Rot45" "Scale0_7" "Scale1_5" "Rot30Scale0_8"];
tforms = { rigidtform2d(15, [0 0]), ...
           rigidtform2d(45, [0 0]), ...
           simtform2d(0.7, 0, [0 0]), ...
           simtform2d(1.5, 0, [0 0]), ...
           simtform2d(0.8, 30, [0 0]) };

nd = numel(options.Detectors);
vals = nan(nd, numel(tforms));
counts = zeros(nd, 1);

for di = 1:nd
    d = options.Detectors(di);
    pts0 = ch14_detect(d, I);
    counts(di) = pts0.Count;
    if pts0.Count == 0, continue, end
    loc0 = pts0.Location;

    for ci = 1:numel(tforms)
        tf = tforms{ci};
        J = imwarp(I, tf, OutputView=R);
        ptsJ = ch14_detect(d, J);
        if ptsJ.Count == 0
            vals(di,ci) = 0;
            continue
        end

        proj = transformPointsForward(tf, loc0);

        % 只算投影後仍在畫面內的點。轉出畫面不是偵測器的錯。
        inside = proj(:,1) >= 1 & proj(:,1) <= size(J,2) & ...
                 proj(:,2) >= 1 & proj(:,2) <= size(J,1);
        if nnz(inside) == 0
            continue                    % 留 NaN，代表這個條件無法評估
        end

        D = pdist2(proj(inside,:), ptsJ.Location);
        vals(di,ci) = 100 * mean(min(D, [], 2) <= options.Tolerance);
    end
end

repeatTbl = array2table(vals, ...
    VariableNames=condNames, ...
    RowNames=options.Detectors);
repeatTbl.NumPoints = counts;
end
