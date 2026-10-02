function s = ch01_imageSummary(I, name)
%CH01_IMAGESUMMARY 摘要一張影像的基本性質，回傳單列 table。
%
%   S = CH01_IMAGESUMMARY(I) 回傳影像 I 的摘要，包含尺寸、類別、通道數、
%   影像型態與數值範圍。
%
%   S = CH01_IMAGESUMMARY(I, NAME) 另外在 Name 欄位填入指定名稱，方便
%   多張影像的摘要用 vertcat 合併成一張表。
%
%   這支函式示範第 01 章「五步驟工作流」的第 ③ 步：把實驗用的零散程式碼
%   收斂成有輸入驗證、有說明、可重複使用的函式。
%
%   範例：
%     I = imread("peppers.png");
%     s = ch01_imageSummary(I, "peppers")
%
%     % 批次用法：搭配 imageDatastore
%     ds = imageDatastore(fullfile(matlabroot,"toolbox","images","imdata"), ...
%                         FileExtensions=[".png" ".tif"]);
%     T = table;
%     while hasdata(ds)
%         [img, info] = read(ds);
%         [~, n] = fileparts(info.Filename);
%         T = [T; ch01_imageSummary(img, n)];
%     end
%
%   另見 IMFINFO, IMAGEDATASTORE, IM2GRAY.

arguments
    I    {mustBeNumericOrLogical, mustBeNonempty}
    name (1,1) string = ""
end

sz       = size(I);
nChan    = size(I, 3);
cls      = string(class(I));

if islogical(I)
    kind = "二值 (binary)";
elseif nChan == 3
    kind = "彩色 (RGB)";
elseif nChan == 1
    kind = "灰階 (grayscale)";
else
    kind = sprintf("多通道 (%d 通道)", nChan);
end

% 以 double 計算範圍，避免整數型別在極值附近溢位
lo = double(min(I(:)));
hi = double(max(I(:)));

% 每像素位元組數 × 像素數
info      = whos("I");
memoryMB  = info.bytes / 1024^2;

s = table(name, sz(1), sz(2), nChan, cls, kind, lo, hi, memoryMB, ...
    VariableNames=["Name" "Height" "Width" "Channels" "Class" "Kind" ...
                   "Min" "Max" "MemoryMB"]);
end
