function [E, info] = ch21_clipEmbed(clip, files, options)
%CH21_CLIPEMBED 批次抽取影像的 CLIP 嵌入（已做 L2 正規化）。
%
%   [E, INFO] = CH21_CLIPEMBED(CLIP, FILES) 對 FILES 逐張抽嵌入，
%   回傳 512-by-N 的矩陣 E（**每一行都已正規化成單位長度**）與計時資訊。
%
%   名稱-值引數：
%     Verbose - 印出進度（預設 false）
%
%   **為什麼一定要正規化**
%
%   CLIP 的影像與文字嵌入活在同一個空間，比較的方式是**餘弦相似度**。
%   若不先正規化，`T' * E` 算出來的是內積，會被向量長度影響——
%   而向量長度和語意無關。
%
%   正規化之後內積就等於餘弦相似度，這也是為什麼
%   CH21_ZEROSHOT 可以直接用矩陣乘法一次算完所有配對。
%
%   **灰階影像要先複製成三通道**（和第 18 章一樣），
%   否則報通道數不符，而訊息不會提到「灰階」。
%
%   **速度**：T550 上約 **0.20 秒／張**（`vit-b-16`）。
%   200 張要 40 秒。比第 18 章的 ResNet-18 特徵抽取
%   （約 0.05 秒／張）慢 4 倍——這是 §10 成本比較的一部分。
%
%   **第一次呼叫要額外約 20 秒**載入模型權重，
%   所以這個函式會先暖機一張再開始計時。
%
%   另見 CH21_ZEROSHOT, CLIPNETWORK, EXTRACTIMAGEEMBEDDINGS.

arguments
    clip
    files (1,:) string {mustBeNonempty}
    options.Verbose (1,1) logical = false
end

% 暖機：第一次呼叫含模型載入
extractImageEmbeddings(clip, prepImage(imread(files(1))));

n = numel(files);
E = [];
t = tic;
for k = 1:n
    e = double(extractImageEmbeddings(clip, prepImage(imread(files(k)))));
    if isempty(E)
        E = zeros(numel(e), n);
    end
    E(:,k) = e(:);
    if options.Verbose && mod(k, 50) == 0
        fprintf("  %d/%d\n", k, n);
    end
end
secTotal = toc(t);

% L2 正規化：之後的內積就等於餘弦相似度
E = E ./ vecnorm(E);

info = struct( ...
    "NumImages",   n, ...
    "Dim",         size(E,1), ...
    "SecTotal",    secTotal, ...
    "SecPerImage", secTotal/n);
end

% ========================================================================
function J = prepImage(I)
if size(I,3) == 1
    I = repmat(I, 1, 1, 3);
end
J = I;
end
