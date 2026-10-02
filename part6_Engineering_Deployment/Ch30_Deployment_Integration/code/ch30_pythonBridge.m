function report = ch30_pythonBridge(options)
%CH30_PYTHONBRIDGE MATLAB ↔ Python 的型別對照與呼叫成本。
%
%   REPORT = CH30_PYTHONBRIDGE() 回傳 struct：
%     Available      這台機器能不能呼叫 Python
%     Version / ExecutionMode
%     TypeMap        table：MATLAB 值 → Python 型別
%     PerCallMs      一次跨邊界呼叫的毫秒數
%     InsideMs       同樣的工作量在 Python 內一次跑完的毫秒數
%     HasNumpy       有沒有 numpy
%
%   ## 最重要的數字是 PerCallMs
%   本機 `pyenv` 的執行模式是 **OutOfProcess**：Python 跑在另一個行程，
%   每次呼叫都要跨行程通訊。兩次實測**一次呼叫 14–16 與 25–31 毫秒**（看負載）——
%   300 次逐一呼叫要 4.5–9 秒，**而同樣 300 次放在一個 `pyrun` 裡在 Python 內跑完
%   只要 24–31 毫秒，和一次呼叫差不多**。傳 8.4 MB 的矩陣也只多幾毫秒。
%   > **成本在跨邊界的次數，不在資料量，也不在運算。**
%   > 把迴圈搬到邊界的同一側——和主教材 §8「每張影像啟動一次 exe」是同一件事。
%
%   ## 型別的坑
%   | MATLAB → Python | Python → MATLAB |
%   |---|---|
%   | double 純量 → float | Python int → **`py.int` 物件**（不會自動變 double） |
%   | 向量、矩陣 → **memoryview**（沒有 numpy 時） | list → `py.list` |
%   | cell → **tuple** | `2**53 + 1` 轉 double **差 1**；轉 int64 才對 |
%   | struct → dict | |
%
%   **本函式不會改動 pyenv 的設定**（ExecutionMode 是持久偏好）。
%
%   名稱-值引數：
%     NumCalls  量開銷時的呼叫次數，預設 300
%
%   另見 PYENV, PYRUN, PYRUNFILE.

arguments
    options.NumCalls (1,1) double {mustBePositive, mustBeInteger} = 300
end

report = struct(Available=false, Version="", ExecutionMode="", ...
    TypeMap=table(), PerCallMs=NaN, InsideMs=NaN, HasNumpy=false, Message="");

try
    pe = pyenv;
    report.Version = string(pe.Version);
    report.ExecutionMode = string(pe.ExecutionMode);
    if strlength(report.Version) == 0
        report.Message = "這台機器沒有設定 Python。";
        return
    end
    pyrun("x_ = 1");
    report.Available = true;
catch ME
    report.Message = string(ME.message);
    return
end

values = {3, int32(3), [1 2 3], magic(3), "abc", 'abc', true, {1, "a"}, struct(a=1)};
labels = ["double 純量" "int32 純量" "double 1×3" "double 3×3" "string" "char" ...
          "logical" "cell 1×2" "struct"];
PythonType = strings(numel(values), 1);
for k = 1:numel(values)
    try
        PythonType(k) = string(py.builtins.str(py.builtins.type(values{k})));
    catch ME
        PythonType(k) = "（失敗）" + extractBefore(string(ME.message) + newline, newline);
    end
end
report.TypeMap = table(labels(:), PythonType, VariableNames=["MATLAB" "Python"]);

pyrun("def ch30_f(x): return x + 1");
pyrun("y_ = ch30_f(1)", "y_");                    % 熱身
n = options.NumCalls;
t0 = tic;
for k = 1:n
    pyrun("y_ = ch30_f(x_)", "y_", x_=k);
end
report.PerCallMs = toc(t0) / n * 1000;
t0 = tic;
pyrun(sprintf("s_ = sum(ch30_f(i) for i in range(%d))", n), "s_");
report.InsideMs = toc(t0) * 1000;

try
    pyrun("import numpy");
    report.HasNumpy = true;
catch
    report.HasNumpy = false;
end
end
