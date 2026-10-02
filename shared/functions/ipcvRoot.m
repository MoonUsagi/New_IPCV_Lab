function root = ipcvRoot()
%IPCVROOT 回傳 IPCV_Lab 課程根目錄的絕對路徑。
%
%   ROOT = IPCVROOT() 以 ipcvSetup.m 的位置推得課程根目錄。若尚未執行
%   ipcvSetup，會擲出帶有指示的錯誤。
%
%   範例：
%     chFolder = fullfile(ipcvRoot(), "part1_ImageProcessing", "Ch01_Image_Basics");
%
%   另見 IPCVSETUP.

p = which("ipcvSetup");
if isempty(p)
    error("ipcv:notSetUp", ...
        "找不到課程根目錄。請先切換到 IPCV_Lab_2026b 資料夾並執行 ipcvSetup。");
end
root = string(fileparts(p));
end
