function [values, report] = ch28_dicomToPhysical(fileName)
%CH28_DICOMTOPHYSICAL 讀 DICOM，轉成物理單位，並**明確回報缺了什麼**。
%
%   [VALUES, REPORT] = CH28_DICOMTOPHYSICAL(FILENAME) 讀一個 DICOM 檔，
%   套用 RescaleSlope／RescaleIntercept，回傳 double 的物理值
%   （CT 是 Hounsfield Unit）。REPORT 是 struct：
%     Modality        CT／MR／US……
%     StoredRange     dicomread 直接給的儲存值範圍
%     PhysicalRange   轉換後的範圍
%     Slope / Intercept
%     HasRescale      檔案裡有沒有 rescale 欄位
%     PixelSpacing    像素間距（mm）；沒有時是 []
%     HasSpacing      有沒有間距資訊
%     Warnings        string 陣列，列出所有缺漏
%
%   ## 為什麼要這支函式
%   **`dicomread` 回傳的是「儲存值」，不是物理值。**
%   本機實測 `CT-MONO2-16-ankle.dcm`：
%   | | 值 |
%   |---|---|
%   | `dicomread` 的範圍 | **32 .. 4080** |
%   | RescaleIntercept | **−1024** |
%   | 轉換後（HU） | **−992 .. 3056** |
%
%   直接拿儲存值當 HU，**所有數字都偏 1024**——
%   空氣（−1000 HU）會被讀成 24，水（0 HU）會被讀成 1024。
%   **用 HU 門檻分割骨頭或肺的程式會完全失效，而且不會報錯。**
%
%   ## 第二個問題：這個檔案**沒有 PixelSpacing**
%   沒有間距就不能量長度與面積。**DICOM 檔不保證有你需要的欄位**，
%   特別是教學用或匿名化過的檔案。這支函式會把缺漏列在 Warnings 裡，
%   **不會安靜地假設 1 mm**。
%
%   > 這和第 25–27 章的「外部長度」是同一件事：
%   > **像素間距是從外面來的資訊，檔案裡沒有就是沒有。**
%
%   另見 DICOMREAD, DICOMINFO, DICOMCOLLECTION, MEDICALVOLUME.

arguments
    fileName (1,1) string
end

info   = dicominfo(fileName);
stored = dicomread(info);

warnings = strings(0,1);

slope = 1;
intercept = 0;
hasRescale = isfield(info, "RescaleSlope") && isfield(info, "RescaleIntercept");
if hasRescale
    slope     = double(info.RescaleSlope);
    intercept = double(info.RescaleIntercept);
else
    warnings(end+1) = "沒有 RescaleSlope／RescaleIntercept：回傳值就是儲存值，" + ...
        "單位未知。對 CT 而言這通常代表資料不能直接當 HU 用。";
end

values = double(stored) * slope + intercept;

spacing = [];
if isfield(info, "PixelSpacing") && ~isempty(info.PixelSpacing)
    spacing = double(info.PixelSpacing(:))';
else
    warnings(end+1) = "沒有 PixelSpacing：無法換算成公釐，任何長度或面積的量測都沒有單位。";
end

modality = "Unknown";
if isfield(info, "Modality")
    modality = string(info.Modality);
end

report = struct( ...
    FileName      = fileName, ...
    Modality      = modality, ...
    StoredClass   = string(class(stored)), ...
    StoredRange   = double([min(stored(:)) max(stored(:))]), ...
    PhysicalRange = [min(values(:)) max(values(:))], ...
    Slope         = slope, ...
    Intercept     = intercept, ...
    HasRescale    = hasRescale, ...
    PixelSpacing  = spacing, ...
    HasSpacing    = ~isempty(spacing), ...
    Size          = size(stored), ...
    Warnings      = warnings);
end
