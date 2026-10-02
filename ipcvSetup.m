function root = ipcvSetup(options)
%IPCVSETUP 設定 IPCV_Lab 課程路徑。每次開啟 MATLAB 後執行一次。
%
%   IPCVSETUP() 將課程所需的資料夾加入 MATLAB 搜尋路徑：setup、
%   shared/functions、shared/data，以及每一章的 code、data、assets 資料夾。
%
%   ROOT = IPCVSETUP() 另外回傳課程根目錄。
%
%   IPCVSETUP(Save=true) 同時把路徑存檔，下次開啟 MATLAB 不需再執行
%   （會寫入 MATLAB 的 pathdef，若無寫入權限則會失敗並提示）。
%
%   IPCVSETUP(Quiet=true) 不列印訊息。
%
%   範例：
%     cd("路徑\到\IPCV_Lab_2026b")
%     ipcvSetup
%     checkEnvironment
%
%   另見 CHECKENVIRONMENT, COURSEREQUIREMENTS, IPCVROOT.

arguments
    options.Save  (1,1) logical = false
    options.Quiet (1,1) logical = false
end

root = fileparts(mfilename("fullpath"));

folders = [
    string(root)                      % 根目錄本身：ipcvRoot 以 which("ipcvSetup") 定位，
                                      % 若根目錄不在路徑上，切換工作目錄後就找不到了
    fullfile(root, "setup")
    fullfile(root, "shared", "functions")
    fullfile(root, "shared", "data")
    fullfile(root, "build")
    ];

% 各章的 code / data / assets 子資料夾
parts = dir(fullfile(root, "part*"));
parts = parts([parts.isdir]);
for p = 1:numel(parts)
    chs = dir(fullfile(parts(p).folder, parts(p).name, "Ch*"));
    chs = chs([chs.isdir]);
    for c = 1:numel(chs)
        base = fullfile(chs(c).folder, chs(c).name);
        folders = [folders
                   fullfile(base, "code")
                   fullfile(base, "data")
                   fullfile(base, "assets")]; %#ok<AGROW>
    end
end

folders = folders(isfolder(folders));
addpath(folders{:});

if options.Save
    try
        savepath;
    catch ME
        warning("ipcv:pathNotSaved", ...
            "路徑已加入但無法存檔（%s）。請改為每次開啟 MATLAB 時執行 ipcvSetup。", ME.message);
    end
end

if ~options.Quiet
    fprintf("IPCV_Lab 課程路徑已設定（%d 個資料夾）\n", numel(folders));
    fprintf("課程根目錄：%s\n", root);
    fprintf("下一步：執行 checkEnvironment 檢查工具箱與支援包。\n");
end

if nargout == 0
    clear root
end
end
