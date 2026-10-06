"""assembleHandbook.py — 把各章 PDF 組成一本手冊。

先執行：
    buildHandbook(Format="docx")                        % MATLAB：重新執行教材並匯出
    powershell -ExecutionPolicy Bypass -File build\\convertHandbookPdf.ps1   % docx → pdf
再執行：
    python build\\assembleHandbook.py [--release R2026b] [--date 2026-09-30]

輸出 build/output/IPCV_Lab_Handbook.pdf：
  封面 → 使用說明 → 全書目錄（含頁碼）→ 31 章
  每一模組、每一章都有 PDF 書籤；封面以外每頁下方置中印頁碼。

需要 Python 套件 pypdf 與 reportlab，以及 Windows 的微軟正黑體（msjh.ttc）。
"""

import argparse
import datetime
import io
import re
from pathlib import Path

from pypdf import PdfReader, PdfWriter
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib import colors
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfgen import canvas
from reportlab.platypus import (PageBreak, Paragraph, SimpleDocTemplate, Spacer,
                                Table, TableStyle)

PARTS = {
    "part0": "Part 0　導論與環境",
    "part1": "Part I　影像處理基礎",
    "part2": "Part II　分割、量測與品質",
    "part3": "Part III　特徵與傳統辨識",
    "part4": "Part IV　AI 視覺",
    "part5": "Part V　動態、3D 與空間視覺",
    "part6": "Part VI　工程化與部署",
}


def register_fonts():
    fonts = Path("C:/Windows/Fonts")
    pdfmetrics.registerFont(TTFont("JH", str(fonts / "msjh.ttc"), subfontIndex=0))
    pdfmetrics.registerFont(TTFont("JHB", str(fonts / "msjhbd.ttc"), subfontIndex=0))


def find_chapters(root: Path):
    out_dir = root / "build" / "output"
    chapters = []
    for readme in sorted(root.glob("part*/Ch*/README.md")):
        m = re.match(r"Ch(\d{2})_", readme.parent.name)
        if not m:
            continue
        num = m.group(1)
        pdf = out_dir / f"Ch{num}_Main.pdf"
        if not pdf.exists():
            raise FileNotFoundError(f"找不到 {pdf}，請先執行 convertHandbookPdf.ps1")
        title = readme.read_text(encoding="utf-8").splitlines()[0].lstrip("#").strip()
        part_key = readme.parent.parent.name.split("_")[0]
        chapters.append(dict(num=num, title=title, pdf=pdf, part=PARTS.get(part_key, part_key),
                             pages=len(PdfReader(str(pdf)).pages)))
    chapters.sort(key=lambda c: c["num"])
    return chapters


def styles():
    base = dict(fontName="JH", leading=22, fontSize=12, wordWrap="CJK")
    return dict(
        title=ParagraphStyle("title", **{**base, "fontName": "JHB", "fontSize": 28, "leading": 40, "alignment": 1}),
        subtitle=ParagraphStyle("subtitle", **{**base, "fontSize": 16, "leading": 26, "alignment": 1,
                                               "textColor": colors.HexColor("#444444")}),
        center=ParagraphStyle("center", **{**base, "alignment": 1, "textColor": colors.HexColor("#555555")}),
        h1=ParagraphStyle("h1", **{**base, "fontName": "JHB", "fontSize": 20, "leading": 30, "spaceAfter": 14,
                                   "textColor": colors.HexColor("#C04000")}),
        body=ParagraphStyle("body", **{**base, "spaceAfter": 8}),
        toc_part=ParagraphStyle("toc_part", **{**base, "fontName": "JHB", "fontSize": 12.5}),
        toc_ch=ParagraphStyle("toc_ch", **{**base, "fontSize": 11.5, "leftIndent": 14}),
    )


def check_layout(chapters):
    """排版檢查：找出沒有轉成表格、以原始 Markdown 印出來的表格。

    verifyChapters 只檢查程式能不能跑，抓不到這類問題。2026-09-24 就在 Ch.12–30 發現
    396 張表因為缺少 %[text:table] 標記（以及分隔列寫成 |---| 而非 | --- |）而原樣印出。
    """
    checks = {
        "原始表格語法（| --- |）": re.compile(r"\|\s*:?-{3,}:?\s*\|"),
        # R2026a 的 Live Editor 會把 %%\n 顯示成 %%n（程式碼裡應改寫成 "%%" + "\n"）
        "被吃掉反斜線的 %%n / %%t": re.compile(r"%%[nt][\"']"),
    }
    problems = []
    for ch in chapters:
        for i, page in enumerate(PdfReader(str(ch["pdf"])).pages):
            text = page.extract_text() or ""
            for name, rx in checks.items():
                if rx.search(text):
                    problems.append((name, ch["num"], i + 1))
    if problems:
        print(f"⚠ 排版檢查：{len(problems)} 處問題，請檢查：")
        for name, num, pg in problems[:30]:
            print(f"    {name}：第 {num} 章　第 {pg} 頁")
    else:
        print("排版檢查：沒有發現原始表格語法或被吃掉的反斜線")
    return problems


def front_matter(chapters, starts, release, date, page_size, measured="R2026a"):
    st = styles()
    story = [Spacer(1, 170),
             Paragraph("IPCV_Lab 影像處理與電腦視覺實作課程", st["title"]),
             Spacer(1, 16),
             Paragraph(f"教材手冊　｜　MATLAB {release} 對標版", st["subtitle"]),
             Paragraph("6 大模組．31 章．約 102 小時", st["subtitle"]),
             Spacer(1, 200),
             Paragraph(f"手冊產生日期：{date}", st["center"]),
             Paragraph(f"所有章節皆在 MATLAB {release} 上重新執行後匯出，圖與輸出都是當次執行的結果", st["center"]),
             PageBreak(),
             Paragraph("如何使用這本手冊", st["h1"])]
    notes = [
        "這本手冊由 31 章的主教材（ChNN_Main.m）重新執行後匯出。每一章的文字、程式碼、輸出與圖都來自同一份檔案，改教材就是改手冊。",
        (f"教材裡的數字都在開發機（MATLAB {release}、NVIDIA T550 4 GB）上實測。"
         + ("少數段落因為缺選用支援包或工具而沒有在 R2026b 重測，保留 R2026a 的數字並在內文加註（清單見 docs/R2026B_MIGRATION.md）；"
            "版本之間會變的結論（例如 Ch.11 的 caliper 預設值、Ch.25 的棋盤格偵測、Ch.26 的 pcfitplane）都寫成兩個版本的對照。"
            if release == "R2026b" else "")
         if measured == release else
         f"<b>教材內文引用的數字大多是在 MATLAB {measured} 上實測的</b>；本手冊的程式輸出則是在 MATLAB {release} 上重新執行的結果，"
         f"兩者若有差異，以輸出為準。已知會隨版本改變的結論（例如 Ch.26 的 pcfitplane）已改寫成兩個版本的對照。")
        + "換一台機器，時間會不同，但結論的方向應該一樣；"
        "教材也一再示範：<b>同一份資料重跑，數字本來就會變</b>，要比的是效應的量級。",
        "每一章另外附有<b>練習與完整解答</b>（exercise 資料夾）、<b>可重用的函式</b>（code 資料夾）與<b>本章摘要</b>（README.md）。"
        "本手冊只收錄主教材；簡報版（IPCV_Lab_Slides.pptx）由各章摘要產生。",
        "全部 31 章主教材與 31 份解答都通過自動驗證（verifyChapters，62/62）。",
        "<b>Ch.18–20 的深度學習訓練段落沒有在開發機上執行</b>（GPU 記憶體不足）；程式碼完整、以旗標關閉，其餘內容都已實測。"
        "<b>Ch.22 使用合成資料</b>：流程已驗證，數字不能當成產線預期。",
        "需要相機、標記、PLC、ARM 或乾淨的部署機器才能驗證的項目，列在專案的 docs/PENDING_VERIFICATION.md。",
        ("本版對標 MATLAB R2026b。與 R2026a 版的差異（產品重組、會報錯的地方、實測翻盤的結論）整理在 "
         "course_plan/05_R2026b更新對照表.md；調整進度見 docs/R2026B_MIGRATION.md。"
         if release == "R2026b" else
         "課程的下一階段將對標 MATLAB R2026b，已知的差異（產品重組、會報錯的地方、實測翻盤的結論）整理在 "
         "course_plan/05_R2026b更新對照表.md。"),
    ]
    for n in notes:
        story.append(Paragraph("• " + n, st["body"]))
    story += [PageBreak(), Paragraph("目錄", st["h1"])]

    rows, style_cmds, last_part = [], [], None
    for ch, start in zip(chapters, starts):
        if ch["part"] != last_part:
            rows.append([Paragraph(ch["part"], st["toc_part"]), ""])
            style_cmds.append(("TOPPADDING", (0, len(rows) - 1), (-1, len(rows) - 1), 10))
            last_part = ch["part"]
        rows.append([Paragraph(ch["title"], st["toc_ch"]),
                     Paragraph(str(start), ParagraphStyle("pn", fontName="JH", fontSize=11.5,
                                                          leading=st["toc_ch"].leading, alignment=2))])
    width = page_size[0] - 144
    table = Table(rows, colWidths=[width - 60, 60])
    table.setStyle(TableStyle([("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
                               ("BOTTOMPADDING", (0, 0), (-1, -1), 2),
                               ("TOPPADDING", (0, 0), (-1, -1), 2)] + style_cmds))
    story.append(table)

    buf = io.BytesIO()
    doc = SimpleDocTemplate(buf, pagesize=page_size, leftMargin=72, rightMargin=72,
                            topMargin=72, bottomMargin=72, title="IPCV_Lab 教材手冊")
    doc.build(story)
    return PdfReader(io.BytesIO(buf.getvalue()))


def page_number_overlay(n_pages, page_size):
    buf = io.BytesIO()
    c = canvas.Canvas(buf, pagesize=page_size)
    for i in range(1, n_pages + 1):
        if i > 1:                                   # 封面不印頁碼
            c.setFont("JH", 9)
            c.setFillColor(colors.HexColor("#666666"))
            c.drawCentredString(page_size[0] / 2, 28, f"— {i} —")
        c.showPage()
    c.save()
    return PdfReader(io.BytesIO(buf.getvalue()))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default=str(Path(__file__).resolve().parents[1]))
    ap.add_argument("--release", default="R2026b")
    ap.add_argument("--measured", default="R2026b", help="教材內文數字是在哪個版本實測的")
    ap.add_argument("--date", default=datetime.date.today().isoformat())
    ap.add_argument("--out", default="IPCV_Lab_Handbook.pdf")
    args = ap.parse_args()

    register_fonts()
    root = Path(args.root)
    chapters = find_chapters(root)
    check_layout(chapters)
    first = PdfReader(str(chapters[0]["pdf"])).pages[0]
    page_size = (float(first.mediabox.width), float(first.mediabox.height))

    # 兩次排版：先假設前置頁數，再用實際頁數重算目錄頁碼
    n_front = 3
    for _ in range(3):
        starts, p = [], n_front + 1
        for ch in chapters:
            starts.append(p)
            p += ch["pages"]
        front = front_matter(chapters, starts, args.release, args.date, page_size, args.measured)
        if len(front.pages) == n_front:
            break
        n_front = len(front.pages)

    writer = PdfWriter()
    for page in front.pages:
        writer.add_page(page)
    for ch in chapters:
        for page in PdfReader(str(ch["pdf"])).pages:
            writer.add_page(page)

    overlay = page_number_overlay(len(writer.pages), page_size)
    for page, stamp in zip(writer.pages, overlay.pages):
        page.merge_page(stamp)

    # 書籤：模組 → 章
    writer.add_outline_item("封面", 0)
    writer.add_outline_item("如何使用這本手冊", 1)
    writer.add_outline_item("目錄", 2)
    parent, last_part = None, None
    for ch, start in zip(chapters, starts):
        if ch["part"] != last_part:
            parent = writer.add_outline_item(ch["part"], start - 1)
            last_part = ch["part"]
        writer.add_outline_item(ch["title"], start - 1, parent=parent)

    writer.add_metadata({"/Title": "IPCV_Lab 影像處理與電腦視覺實作課程 — 教材手冊",
                         "/Subject": f"MATLAB {args.release} 對標版，31 章"})
    out = root / "build" / "output" / args.out
    with open(out, "wb") as f:
        writer.write(f)
    print(f"完成：{out}")
    print(f"  前置 {n_front} 頁 + 31 章 {sum(c['pages'] for c in chapters)} 頁 = {len(writer.pages)} 頁，"
          f"{out.stat().st_size / 1e6:.1f} MB")


if __name__ == "__main__":
    main()
