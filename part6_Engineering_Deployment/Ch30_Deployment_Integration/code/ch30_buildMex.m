function info = ch30_buildMex(options)
%CH30_BUILDMEX 用 MATLAB Coder 把 ch30_countGrainsCG 編成 MEX 或 C 函式庫（有快取）。
%
%   INFO = CH30_BUILDMEX() 產生固定大小（256×256 uint8）的 MEX，
%   回傳 struct：Kind、Name、Folder、Seconds、Cached、Success、Message。
%
%   INFO = CH30_BUILDMEX(Kind="variable") 產生可變大小（最大 4096×4096）的 MEX。
%   INFO = CH30_BUILDMEX(Kind="lib") 產生 C 靜態函式庫的原始碼，並統計行數。
%
%   ## 快取
%   codegen 很慢（本機 40–75 秒）。產物放在 `tempdir/ch30_build`，
%   **原始檔沒有比產物新就直接重用**。`Force=true` 強制重建。
%
%   ## 一個環境陷阱：NoDefaultCurrentDirectoryInExePath
%   codegen 產生 `xxx_mex.bat` 之後，用**不帶路徑**的名字呼叫它。
%   如果行程環境裡有 `NoDefaultCurrentDirectoryInExePath`（某些安全強化
%   工具與終端機會設），cmd **不會在當前目錄找批次檔**，建置失敗並顯示
%   「'xxx_mex.bat' 不是內部或外部命令」——**連 `y = x + 1` 都編不過**，
%   而 `mex hello.c` 卻正常。
%
%   本函式在呼叫 codegen 前**只在 MATLAB 行程內**清掉這個變數（不動系統設定），
%   並在 INFO.EnvWorkaround 記錄是否有這樣做。
%
%   另見 CODEGEN, CODER.CONFIG, CODER.TYPEOF, CH30_COUNTGRAINSCG.

arguments
    options.Kind  (1,1) string {mustBeMember(options.Kind, ["fixed" "variable" "lib"])} = "fixed"
    options.Force (1,1) logical = false
end

buildRoot = fullfile(tempdir, "ch30_build");
if ~isfolder(buildRoot)
    mkdir(buildRoot);
end
source = which("ch30_countGrainsCG");
srcInfo = dir(source);

envWorkaround = false;
if ~isempty(getenv("NoDefaultCurrentDirectoryInExePath"))
    setenv("NoDefaultCurrentDirectoryInExePath", "");
    envWorkaround = true;
end

switch options.Kind
    case "fixed"
        name = "ch30_countGrainsCG_mex";
        product = fullfile(buildRoot, name + "." + mexext);
        args = {zeros(256, 256, "uint8"), 15, 50, -1};
    case "variable"
        name = "ch30_countGrainsCG_var_mex";
        product = fullfile(buildRoot, name + "." + mexext);
        args = {coder.typeof(uint8(0), [4096 4096], [true true]), 15, 50, -1};
    case "lib"
        name = "ch30_lib";
        product = fullfile(buildRoot, name, "ch30_countGrainsCG.c");
        args = {zeros(256, 256, "uint8"), 15, 50, -1};
end

info = struct(Kind=options.Kind, Name=name, Folder=buildRoot, Seconds=0, ...
    Cached=false, Success=false, Message="", EnvWorkaround=envWorkaround, ...
    NumCFiles=0, NumCLines=0, Signature="");

if ~options.Force && isfile(product) && dir(product).datenum >= srcInfo.datenum
    info.Cached  = true;
    info.Success = true;
else
    here = pwd;
    back = onCleanup(@() cd(here));
    cd(buildRoot);
    t0 = tic;
    try
        if options.Kind == "lib"
            cfg = coder.config("lib");
            cfg.GenerateReport = false;
            codegen("-config", cfg, "ch30_countGrainsCG", "-args", args, "-d", name);
        else
            codegen("ch30_countGrainsCG", "-args", args, "-o", name);
        end
        info.Success = true;
    catch ME
        info.Message = string(ME.message);
    end
    info.Seconds = toc(t0);
end

if info.Success && options.Kind ~= "lib"
    addpath(buildRoot);
end
if info.Success && options.Kind == "lib"
    libDir = fullfile(buildRoot, name);
    cFiles = dir(fullfile(libDir, "*.c"));
    info.NumCFiles = numel(cFiles);
    n = 0;
    for k = 1:numel(cFiles)
        n = n + numel(splitlines(fileread(fullfile(libDir, cFiles(k).name))));
    end
    info.NumCLines = n;
    header = splitlines(string(fileread(fullfile(libDir, "ch30_countGrainsCG.h"))));
    sig = header(contains(header, "extern void ch30_countGrainsCG("));
    if ~isempty(sig)
        k = find(header == sig(1), 1);
        e = k - 1 + find(contains(header(k:end), ");"), 1);
        info.Signature = strjoin(strtrim(header(k:e)), " ");
    end
end
end
