function [nInserted, maxIoU, scene, boxes] = ch13_fillScene(dest, srcObj, objMask, maxOverlap, maxObjects, options)
%CH13_FILLSCENE 反覆插入物件直到放不下，回傳實際插入數與最大重疊。
%
%   [N, MAXIOU] = CH13_FILLSCENE(DEST, SRCOBJ, OBJMASK, MAXOVERLAP, MAXOBJECTS)
%   [N, MAXIOU, SCENE, BOXES] = CH13_FILLSCENE(___) 另外回傳合成影像與框。
%
%   名稱-值引數：
%     Scale       幾何擴增的縮放範圍，預設 [0.7 0.9]
%     Attempts    每次插入的最大嘗試次數，預設 50
%
%   處理了一個 API 陷阱
%   -------------------
%   `insertObjectInImage` 的 `ObjectsInSceneMasks` **不接受空值**。
%   第一次插入時還沒有任何已放置的物件，若照直覺傳一個 0 通道的陣列，
%   會得到：
%
%     Invalid value for 'ObjectsInSceneMasks' argument. Value must not be empty.
%
%   正確做法是**第一次呼叫時省略這個參數**，之後才傳累積的遮罩堆疊。
%   本函式用動態引數列表處理這件事。
%
%   重疊限制的取捨（第 13 章第 10 節實測）
%   --------------------------------------
%   畫布 260x320、物件縮放 0.7–0.9：
%
%     MaxOverlap   插入個數   最大實際 IoU
%       1.0（預設）    10        0.7794
%       0.5             2        0.0000
%       0.2             2        0.0000
%       0.0             2        0.0000
%
%   **預設值 1 代表完全不限制重疊**，結果是十個物件疊在一起，
%   最嚴重的一對重疊 78%。那種標註對訓練是有害的——
%   兩個框幾乎重合，模型學不到「一個物件對應一個框」。
%
%   但只要收到 0.5，就只塞得進 2 個——**資料量掉 5 倍**。
%   而且 0.5 / 0.2 / 0 三個值結果相同：限制一旦生效就直接飽和。
%
%   > **這是合成資料的核心取捨：擠得越多標註越差，標註越乾淨資料越少。**
%   > 沒有正確答案——要看你的真實場景有多擁擠。
%   > 真實場景本來就會遮擋，就**應該**允許重疊；
%   > 不會遮擋卻允許，就是在製造真實世界不存在的樣本。
%
%   範例：
%     dest = imresize(imread("saturn.png"), [260 320]);
%     [n, iou] = ch13_fillScene(dest, srcObj, objMask, 0.5, 10);
%     fprintf("插入 %d 個，最大 IoU %.4f\n", n, iou);
%
%   另見 INSERTOBJECTINIMAGE, CH13_MAKESYNTHETICSET, BBOXOVERLAPRATIO.

arguments
    dest    {mustBeNumeric, mustBeNonempty}
    srcObj  {mustBeNumeric, mustBeNonempty}
    objMask {mustBeA(objMask, ["logical" "numeric"])}
    maxOverlap (1,1) double {mustBeInRange(maxOverlap, 0, 1)}
    maxObjects (1,1) double {mustBePositive, mustBeInteger}
    options.Scale    (1,2) double {mustBePositive} = [0.7 0.9]
    options.Attempts (1,1) double {mustBePositive, mustBeInteger} = 50
end

if exist("insertObjectInImage", "file") == 0
    error("ch13_fillScene:noAVI", ...
        "找不到 insertObjectInImage。需要 " + ...
        "Automated Visual Inspection Library for Computer Vision Toolbox。");
end

if ~islogical(objMask), objMask = logical(objMask); end

scene = dest;
stack = [];
boxes = zeros(0, 4);
sc    = options.Scale;

for k = 1:maxObjects
    args = {scene, srcObj, objMask, ...
        "GeometricAugmentation", @() randomAffine2d(Scale=sc), ...
        "MaxInsertionAttempts", options.Attempts};

    % 關鍵：第一次不要傳 ObjectsInSceneMasks（它不接受空值）
    if ~isempty(stack)
        args = [args, {"ObjectsInSceneMasks", stack, ...
                       "ObjectsInSceneMaxOverlap", maxOverlap}];
    end

    try
        [scene, bb, nm] = insertObjectInImage(args{:});
    catch ME
        if k == 1
            rethrow(ME);            % 第一次就失敗是真的有問題
        end
        break                       % 之後失敗代表放不下了
    end

    if isempty(bb) || ~any(nm(:))
        break                       % 嘗試次數用完，放不下
    end

    if isempty(stack)
        stack = nm;
    else
        stack = cat(3, stack, nm);
    end
    boxes = [boxes; bb];
end

nInserted = size(boxes, 1);

maxIoU = 0;
if nInserted >= 2
    vals = zeros(1, nInserted*(nInserted-1)/2);
    idx = 0;
    for a = 1:nInserted
        for b = a+1:nInserted
            idx = idx + 1;
            vals(idx) = bboxOverlapRatio(boxes(a,:), boxes(b,:));
        end
    end
    maxIoU = max(vals);
end
end
