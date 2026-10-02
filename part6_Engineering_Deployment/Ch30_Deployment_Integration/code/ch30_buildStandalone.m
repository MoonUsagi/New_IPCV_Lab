function info = ch30_buildStandalone(options)
%CH30_BUILDSTANDALONE 用 MATLAB Compiler 把命令列版顆粒計數打包成 exe（有快取）。
%
%   INFO = CH30_BUILDSTANDALONE() 打包 ch30_grainCLI，回傳 struct：
%     ExeMB             執行檔大小
%     BuildSeconds      建置時間（快取時為 0）
%     RunSeconds        執行一次的時間（**含 MATLAB Runtime 啟動**）
%     Output            執行檔的輸出
%     SupportPackages   包進去的支援包清單
%     Cached / Success / Message
%
%   INFO = CH30_BUILDSTANDALONE(SupportPackages="autodetect") 用預設的自動偵測。
%
%   ## 本機實測
%   | 選項 | exe 大小 | 建置 |
%   |---|---|---|
%   | 預設（自動偵測支援包） | **619.8 MB** | 66.7 秒 |
%   | **`SupportPackages="none"`** | **1.5 MB** | 21.4 秒 |
%
%   自動偵測把**高光譜函式庫、圓形偵測模型、Segment Anything Model**
%   全部包了進去——一支 10 行、只用 `imopen`／`imbinarize` 的程式，
%   **大了 413 倍，全是沒用到的模型權重**。
%   > 看 `includedSupportPackages.txt`，那是打包後第一個該檢查的檔案。
%
%   ## 另一個數字：執行一次要 18 秒
%   運算本身只要約 20 毫秒，其餘全是 **MATLAB Runtime 的啟動**。
%   **每張影像啟動一次 exe 在產線上不可行**——要嘛讓程式常駐、
%   一次處理一批；要嘛用 MATLAB Production Server 之類的服務；
%   要嘛用 MATLAB Coder 產生不需要 Runtime 的 C 程式碼（§2）。
%
%   **目標機器需要安裝 MATLAB Runtime**（和 MATLAB 版本一致，數 GB）。
%   本機因為裝了 MATLAB，Runtime 已經在 PATH 上。
%
%   名稱-值引數：
%     SupportPackages  "none"（預設）或 "autodetect"
%     Force            強制重建，預設 false
%
%   另見 COMPILER.BUILD.STANDALONEAPPLICATION, ISDEPLOYED, MCC.

arguments
    options.SupportPackages (1,1) string {mustBeMember(options.SupportPackages, ["none" "autodetect"])} = "none"
    options.Force (1,1) logical = false
end

buildRoot = fullfile(tempdir, "ch30_standalone_" + options.SupportPackages);
source = which("ch30_grainCLI");
exeFile = fullfile(buildRoot, "ch30_grainCLI.exe");

info = struct(ExeMB=NaN, BuildSeconds=0, RunSeconds=NaN, Output="", ...
    SupportPackages=strings(0,1), Cached=false, Success=false, Message="");

if ~isempty(getenv("NoDefaultCurrentDirectoryInExePath"))
    setenv("NoDefaultCurrentDirectoryInExePath", "");
end

if ~options.Force && isfile(exeFile) && dir(exeFile).datenum >= dir(source).datenum
    info.Cached = true;
else
    if isfolder(buildRoot)
        rmdir(buildRoot, "s");
    end
    t0 = tic;
    try
        compiler.build.standaloneApplication(source, OutputDir=buildRoot, ...
            Verbose="off", SupportPackages=options.SupportPackages);
    catch ME
        info.Message = string(ME.message);
        return
    end
    info.BuildSeconds = toc(t0);
end

info.Success = isfile(exeFile);
if ~info.Success
    info.Message = "找不到產生的執行檔。";
    return
end
info.ExeMB = dir(exeFile).bytes / 1e6;
spFile = fullfile(buildRoot, "includedSupportPackages.txt");
if isfile(spFile)
    lines = strtrim(splitlines(string(fileread(spFile))));
    info.SupportPackages = lines(strlength(lines) > 0);
end

testImage = which("rice.png");
t0 = tic;
[status, out] = system(sprintf('"%s" "%s"', exeFile, testImage));
info.RunSeconds = toc(t0);
info.Output = strtrim(string(out));
if status ~= 0
    info.Success = false;
    info.Message = "執行檔回傳非零狀態：" + info.Output;
end
end
