function info = ch30_buildGpuMex(options)
%CH30_BUILDGPUMEX 用 GPU Coder 把 ch30_countGrainsGPU 編成 CUDA MEX（有快取）。
%
%   INFO = CH30_BUILDGPUMEX() 以**編譯時常數的背景半徑 15**、可變大小輸入
%   （最大 4096×4096）建置 ch30_countGrainsGPU_mex。回傳 struct：
%   Name、Folder、Seconds、Cached、Success、Message、Radius。
%
%   INFO = CH30_BUILDGPUMEX(Build=false) 只檢查快取，不存在時不建置
%   （GPU Coder 建置一次要數分鐘）。
%
%   ## 為什麼半徑要是常數
%   本機實測同一段前處理（im2double → imopen → graythresh → imbinarize）：
%   | 半徑 | 建置 | 每次呼叫 |
%   |---|---|---|
%   | 程式碼裡寫死 15 | 56 秒 | **約 1 ms** |
%   | 當成輸入參數傳入 | 345 秒 | **約 102 秒** |
%   結果完全一樣，差了約 10 萬倍。CPU 的 MEX 沒有這個問題（§3 的四個半徑都很快）。
%   我沒有追到產生的 CUDA 程式碼裡是哪一段造成的；可以確定的是
%   **「執行期才知道的結構元素」在 GPU 碼生成裡代價極高**。
%
%   用 `coder.Constant(15)` 當建置引數，半徑在編譯時固定。
%   **呼叫時仍然要傳 15**；傳 10 會報「Run-time value of constant argument
%   'backgroundRadius' must be the same as value at code generation time」。
%
%   即使這樣，完整函式（本機，結果與 MATLAB 完全一致）仍然比 MATLAB 慢：
%   256² 每次 1.5 秒（MATLAB 11 ms）、2048² 每次 12.3 秒（MATLAB 443 ms）。
%   建置時 GPU Coder 警告「GPU code generation for Variable input sizes is not optimized」。
%
%   另見 CODER.GPUCONFIG, CODER.CONSTANT, CH30_COUNTGRAINSGPU, CH30_BUILDMEX.

arguments
    options.Build (1,1) logical = true
    options.Force (1,1) logical = false
end

buildRoot = fullfile(tempdir, "ch30_build_gpu");
if ~isfolder(buildRoot)
    mkdir(buildRoot);
end
name = "ch30_countGrainsGPU_mex";
product = fullfile(buildRoot, name + "." + mexext);
source = which("ch30_countGrainsGPU");
radius = 15;

info = struct(Name=name, Folder=buildRoot, Seconds=0, Cached=false, ...
    Success=false, Message="", Radius=radius);

if ~isempty(getenv("NoDefaultCurrentDirectoryInExePath"))
    setenv("NoDefaultCurrentDirectoryInExePath", "");
end

if ~options.Force && isfile(product) && dir(product).datenum >= dir(source).datenum
    info.Cached = true;
    info.Success = true;
elseif ~options.Build
    info.Message = "尚未建置（Build=false）。";
    return
else
    here = pwd;
    back = onCleanup(@() cd(here));
    cd(buildRoot);
    t0 = tic;
    try
        cfg = coder.gpuConfig("mex");
        cfg.GenerateReport = false;
        codegen("-config", cfg, "ch30_countGrainsGPU", "-args", ...
            {coder.typeof(uint8(0), [4096 4096], [true true]), coder.Constant(radius), 50, -1}, ...
            "-o", name, "-d", fullfile(buildRoot, "codegen"));
        info.Success = true;
    catch ME
        info.Message = string(ME.message);
    end
    info.Seconds = toc(t0);
end
if info.Success
    addpath(buildRoot);
end
end
