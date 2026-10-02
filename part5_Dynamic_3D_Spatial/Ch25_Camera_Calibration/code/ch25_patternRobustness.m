function report = ch25_patternRobustness(options)
%CH25_PATTERNROBUSTNESS 比較 ChArUco 與棋盤格在遮擋下的穩健性。
%
%   REPORT = CH25_PATTERNROBUSTNESS() 對兩種標定圖樣逐步加大遮擋，
%   記錄各自還偵測得到幾個點，回傳 table：
%     Occlusion        遮擋比例
%     CharucoPoints    ChArUco 偵測到的角點數（滿分 24）
%     CheckerPoints    棋盤格偵測到的角點數（滿分 54）
%     CharucoOK        ChArUco 是否給出正確點數
%     CheckerOK        棋盤格是否給出正確點數
%
%   ## 為什麼 ChArUco 比較穩健
%   棋盤格的角點**沒有身分**——偵測器必須看到完整的矩形陣列，
%   才能推斷每個角點對應到世界座標的哪一格。
%   ChArUco 在每個白格裡放一個 **ArUco 標記**，每個標記有唯一的 ID，
%   所以**只要看得到一部分，就能算出那部分角點的世界座標**。
%
%   ## 實測到一個更嚴重的問題
%   遮住 40% 時，棋盤格偵測器回傳 **63 個點——比滿分 54 還多**，
%   而且只發了一個關於「棋盤必須是非對稱」的警告。
%   它把剩下的區域當成**另一個尺寸的棋盤**偵測成功了。
%
%   > **這不是「偵測失敗」，是「偵測出一個錯的答案並且回報成功」。**
%   > 拿那 63 個點去標定，`estimateCameraParameters` 也會照常執行，
%   > 給你一組看起來很正常的內參。
%   > **所以標定流程一定要檢查偵測到的點數是否等於預期值。**
%
%   名稱-值引數：
%     Occlusions   遮擋比例向量，預設 [0 0.1 0.2 0.3 0.4 0.5]
%     BoardDims    ChArUco 的格數，預設 [7 5]
%     MarkerFamily 預設 "DICT_4X4_1000"
%
%   > **`generateCharucoBoard` 與 `detectCharucoBoardPoints`
%   > 接受的字典清單不一樣。** 產生器吃 `DICT_4X4_50`，
%   > 偵測器只吃 `DICT_4X4_1000`／`DICT_5X5_1000`／`DICT_6X6_1000`／
%   > `DICT_7X7_1000`／`DICT_ARUCO_ORIGINAL`。
%   > 用產生器接受、偵測器不接受的字典，會在**偵測**那一步才報錯。
%
%   另見 GENERATECHARUCOBOARD, DETECTCHARUCOBOARDPOINTS,
%   DETECTCHECKERBOARDPOINTS, PATTERNWORLDPOINTS.

arguments
    options.Occlusions   (1,:) double = [0 0.1 0.2 0.3 0.4 0.5]
    options.BoardDims    (1,2) double = [7 5]
    options.MarkerFamily (1,1) string = "DICT_4X4_1000"
end

checkerSize = 100;
markerSize  = 70;
charucoImg = generateCharucoBoard([700 500], options.BoardDims, ...
    options.MarkerFamily, checkerSize, markerSize);

checkerImg = imread(fullfile(toolboxdir("vision"), "visiondata", ...
    "calibration", "mono", "image01.jpg"));

expectedCharuco = size(patternWorldPoints("charuco-board", ...
    options.BoardDims, checkerSize), 1);
expectedChecker = size(detectCheckerboardPoints(checkerImg), 1);

n = numel(options.Occlusions);
Occlusion     = options.Occlusions(:);
CharucoPoints = zeros(n,1);
CheckerPoints = zeros(n,1);

for i = 1:n
    frac = options.Occlusions(i);

    ci = charucoImg;
    h = round(size(ci,1) * frac);
    if h > 0, ci(1:h, :) = 255; end
    CharucoPoints(i) = size(detectCharucoBoardPoints(ci, options.BoardDims, ...
        options.MarkerFamily, checkerSize, markerSize), 1);

    bi = checkerImg;
    h = round(size(bi,1) * frac);
    if h > 0, bi(1:h, :, :) = 255; end
    % 棋盤格在重度遮擋下會發「必須非對稱」的警告，而且仍然回傳結果。
    % 這裡把警告關掉，因為**我們要量的正是「它不報錯就給錯答案」**。
    w = warning("off", "vision:calibrate:boardShouldBeAsymmetric");
    CheckerPoints(i) = size(detectCheckerboardPoints(bi), 1);
    warning(w);
end

CharucoOK = CharucoPoints == expectedCharuco;
CheckerOK = CheckerPoints == expectedChecker;

report = table(Occlusion, CharucoPoints, CheckerPoints, CharucoOK, CheckerOK);
report.Properties.UserData = struct( ...
    ExpectedCharuco = expectedCharuco, ...
    ExpectedChecker = expectedChecker);
end
