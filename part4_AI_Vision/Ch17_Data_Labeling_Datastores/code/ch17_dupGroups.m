function [groupId, S, info] = ch17_dupGroups(files, options)
%CH17_DUPGROUPS 找出資料集裡的「近重複」影像，並把它們分成群組。
%
%   [GROUPID, S, INFO] = CH17_DUPGROUPS(FILES) 讀入 FILES（字串陣列）裡的
%   每張影像，縮到小尺寸後計算兩兩餘弦相似度，把相似度超過門檻的影像
%   視為近重複並歸到同一群。
%
%   回傳：
%     GROUPID - 每張影像的群組編號（同群 = 互為近重複）
%     S       - 相似度矩陣（對角線已設為 -Inf）
%     INFO    - struct，含 NumGroups、NumWithPartner、GroupSizes
%
%   名稱-值引數：
%     Threshold - 判定近重複的相似度門檻（預設 0.99）
%     Size      - 比較用的縮圖尺寸（預設 [32 32]）
%
%   **為什麼需要這個函式**
%
%   資料切分的目的是讓測試集回答「模型沒見過的資料表現如何」。
%   若同一張（或幾乎同一張）影像同時出現在訓練集與測試集，
%   測試分數量到的是**記憶**，不是泛化。
%
%   而「隨機切分」**不保證**避開這件事——隨機切分只保證每張影像
%   被分到哪一邊是隨機的，它不知道哪些影像彼此重複。
%
%   實測（vision 的 vehicles 資料集，295 張，門檻 0.99）：
%
%     244 個群組：197 個單張、45 個成對、2 個四張一組
%     98 張影像（33%）有至少一個近重複夥伴
%     最大的群組是 [37 38 283 284]——**重複的影像不相鄰**
%
%   跨集合近重複比例（測試影像中，有 >0.99 夥伴在訓練集裡的比例）：
%
%     隨機切分        27%
%     區塊切分        41%
%     **群組感知切分   0%**
%
%   **注意區塊切分比隨機切分更糟。** 我原本假設這個資料集是連續影格、
%   所以隨機切分會洩漏、按順序切會安全——**量出來剛好相反**。
%   原因是重複的影像成對出現在資料集的**兩個不同位置**
%   （37/38 與 283/284），按順序切會把一對拆到兩邊。
%
%   所以結論不是「用某一種切法」，而是：
%   **重複情形要量，不能假設。** 量完之後用群組感知切分。
%
%   實作方式的取捨：這裡用「縮圖 + 餘弦相似度」，快且夠用
%   （295 張影像的完整相似度矩陣不到一秒）。它抓得到
%   重新編碼、輕微裁切、亮度微調的重複，抓不到
%   大幅裁切或幾何變換的重複。要更嚴謹可以換成
%   感知雜湊（perceptual hash）或深度特徵嵌入。
%
%   另見 CH17_COMPARESPLITS, IMAGEDATASTORE.

arguments
    files (1,:) string {mustBeNonempty}
    options.Threshold (1,1) double {mustBeInRange(options.Threshold,-1,1)} = 0.99
    options.Size      (1,2) double {mustBePositive, mustBeInteger} = [32 32]
end

n = numel(files);
d = prod(options.Size);
F = zeros(n, d);

for k = 1:n
    I = imread(files(k));
    if size(I,3) > 1
        I = im2gray(I);
    end
    J = imresize(im2double(I), options.Size);
    % 減去平均值再正規化 = 相關係數；這樣亮度偏移不會被當成差異
    F(k,:) = J(:)' - mean(J(:));
end

nrm = vecnorm(F, 2, 2);
nrm(nrm == 0) = 1;                  % 全白／全黑的影像不要除以 0
F = F ./ nrm;

S = F * F.';
S(1:n+1:end) = -Inf;                % 每張影像和自己當然相同，排除掉

adj = S > options.Threshold;
G = graph(adj, 'omitselfloops');
groupId = conncomp(G).';

sizes = accumarray(groupId, 1);
info = struct( ...
    "NumGroups",      numel(sizes), ...
    "NumWithPartner", nnz(sizes(groupId) > 1), ...
    "GroupSizes",     sizes, ...
    "Threshold",      options.Threshold);

if info.NumWithPartner > 0
    warning("ch17_dupGroups:duplicatesFound", ...
        "%d 張影像（%.0f%%）有近重複夥伴。" + ...
        "**隨機切分會把它們拆到訓練集與測試集兩邊**，" + ...
        "讓測試分數偏高。請改用群組感知切分（見 ch17_compareSplits）。", ...
        info.NumWithPartner, 100*info.NumWithPartner/n);
end
end
