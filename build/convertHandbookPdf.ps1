# convertHandbookPdf.ps1
# 把 buildHandbook(Format="docx") 產生的 ChNN_Main.docx 逐一轉成 ChNN_Main.pdf（同一個資料夾）。
# 需要 Windows + Microsoft Word（COM 自動化）。每章約 10 秒。
#
# 轉完之後執行 assembleHandbook.py 組成整本手冊：
#   powershell -ExecutionPolicy Bypass -File build\convertHandbookPdf.ps1
#   python build\assembleHandbook.py
#
# 為什麼不在 Word 裡直接合併：實測用 InsertFile 合併 3 章再更新目錄，
# 跑了 20 分鐘以上沒有結束；單章轉 PDF 只要約 10 秒。

param(
    [string]$Root = (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
)
$ErrorActionPreference = "Stop"
$outDir = Join-Path $Root "build\output"
$files = Get-ChildItem -Path (Join-Path $outDir "Ch*_Main.docx") | Sort-Object Name
if ($files.Count -eq 0) { throw "build\output 裡沒有 Ch*_Main.docx，請先執行 buildHandbook(Format=""docx"")。" }

$word = New-Object -ComObject Word.Application
$word.Visible = $false
$word.DisplayAlerts = 0
try {
    foreach ($f in $files) {
        $pdf = [System.IO.Path]::ChangeExtension($f.FullName, ".pdf")
        $t = [Diagnostics.Stopwatch]::StartNew()
        $doc = $word.Documents.Open($f.FullName, $false, $true)
        $pages = $doc.ComputeStatistics(2)
        $doc.SaveAs2($pdf, 17)
        $doc.Close($false)
        Write-Host ("  {0}  {1,4} 頁  {2,5:N1} 秒" -f $f.Name, $pages, $t.Elapsed.TotalSeconds)
    }
}
finally {
    $word.Quit()
    [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($word)
}
Write-Host ("完成：{0} 個 PDF" -f $files.Count)
