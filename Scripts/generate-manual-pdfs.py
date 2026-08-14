#!/usr/bin/env python3
"""Generate the public CodexVault manuals as visually checked PDF documents."""

from __future__ import annotations

import re
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.platypus import (
    Image,
    PageBreak,
    Paragraph,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)


ROOT = Path(__file__).resolve().parent.parent
SOURCE_DIR = ROOT / "Scripts" / "ManualSources"
OUTPUT_DIR = ROOT / "docs"
ICON_PATH = ROOT / "Assets" / "AppIcon" / "CodexVault-Transparent.png"

MANUALS = (
    ("MANUAL.en.txt", "CodexVault-Manual-EN.pdf", "CodexVault Manual", "Local backup and restore guide"),
    ("MANUAL.de.txt", "CodexVault-Handbuch-DE.pdf", "CodexVault Handbuch", "Lokaler Backup- und Wiederherstellungsleitfaden"),
)

# CodexVault's public manuals deliberately use the same dark, blue-forward
# palette as the app. Keeping this here (rather than in a document template)
# makes the PDFs reproducible from the text sources.
INK = colors.HexColor("#EAF1F8")
MUTED = colors.HexColor("#AAB9C8")
BLUE = colors.HexColor("#169BFF")
CYAN = colors.HexColor("#48C7E8")
SURFACE = colors.HexColor("#182533")
PAGE = colors.HexColor("#111A24")
BORDER = colors.HexColor("#385066")
ROW = colors.HexColor("#203141")
SIDEBAR = colors.HexColor("#38546B")
HEADER = colors.HexColor("#10171F")


def paragraph_markup(text: str) -> str:
    """Convert the small Markdown subset used by the manuals to ReportLab XML."""
    text = text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
    text = re.sub(r"`([^`]+)`", r'<font name="Courier">\1</font>', text)
    text = re.sub(r"\*\*([^*]+)\*\*", r"<b>\1</b>", text)
    return text


def make_styles():
    styles = getSampleStyleSheet()
    return {
        "title": ParagraphStyle(
            "ManualTitle", parent=styles["Title"], fontName="Helvetica-Bold",
            fontSize=27, leading=32, textColor=INK,
            alignment=TA_CENTER, spaceAfter=3.5 * mm,
        ),
        "eyebrow": ParagraphStyle(
            "ManualEyebrow", parent=styles["BodyText"], fontName="Helvetica-Bold",
            fontSize=8.6, leading=11, textColor=BLUE,
            alignment=TA_CENTER, spaceAfter=1.8 * mm,
        ),
        "h1": ParagraphStyle(
            "ManualHeading1", parent=styles["Heading1"], fontName="Helvetica-Bold",
            fontSize=17.5, leading=22, textColor=INK,
            spaceBefore=7.2 * mm, spaceAfter=3.2 * mm,
        ),
        "h2": ParagraphStyle(
            "ManualHeading2", parent=styles["Heading2"], fontName="Helvetica-Bold",
            fontSize=12.7, leading=16.5, textColor=BLUE,
            spaceBefore=5.2 * mm, spaceAfter=2 * mm,
        ),
        "body": ParagraphStyle(
            "ManualBody", parent=styles["BodyText"], fontName="Helvetica",
            fontSize=9.8, leading=14, textColor=INK,
            spaceAfter=2.35 * mm,
        ),
        "bullet": ParagraphStyle(
            "ManualBullet", parent=styles["BodyText"], fontName="Helvetica",
            fontSize=9.8, leading=14, leftIndent=5.6 * mm, firstLineIndent=-3.8 * mm,
            textColor=INK, spaceAfter=1.5 * mm,
        ),
        "number": ParagraphStyle(
            "ManualNumber", parent=styles["BodyText"], fontName="Helvetica",
            fontSize=9.8, leading=14, leftIndent=7.4 * mm, firstLineIndent=-5.3 * mm,
            textColor=INK, spaceAfter=1.65 * mm,
        ),
        "link": ParagraphStyle(
            "ManualLink", parent=styles["BodyText"], fontName="Helvetica-Oblique",
            fontSize=8.8, leading=12, textColor=MUTED,
            alignment=TA_CENTER, spaceAfter=4.5 * mm,
        ),
    }


def table_flowable(rows: list[list[str]], styles):
    data = [[Paragraph(paragraph_markup(cell), styles["body"]) for cell in row] for row in rows]
    width = A4[0] - 36 * mm
    col_widths = [width / len(rows[0])] * len(rows[0])
    table = Table(data, colWidths=col_widths, repeatRows=1, hAlign="LEFT")
    table.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#174D76")),
        ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
        ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
        ("GRID", (0, 0), (-1, -1), 0.35, BORDER),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("LEFTPADDING", (0, 0), (-1, -1), 3.6 * mm),
        ("RIGHTPADDING", (0, 0), (-1, -1), 3.6 * mm),
        ("TOPPADDING", (0, 0), (-1, -1), 2.5 * mm),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 2.5 * mm),
        ("ROWBACKGROUNDS", (0, 1), (-1, -1), [SURFACE, ROW]),
    ]))
    return [Spacer(1, 1.5 * mm), table, Spacer(1, 2 * mm)]


def screenshot_flowable(relative_path: str, caption: str, styles):
    """Return a constrained screenshot and caption for a Markdown image line."""
    image_path = ROOT / relative_path
    if not image_path.exists():
        raise FileNotFoundError(f"Manual screenshot is missing: {image_path}")
    image = Image(str(image_path))
    image._restrictSize(A4[0] - 44 * mm, 92 * mm)
    image.hAlign = "CENTER"
    return [
        Spacer(1, 1.5 * mm),
        image,
        Spacer(1, 1.3 * mm),
        Paragraph(paragraph_markup(caption), styles["link"]),
        Spacer(1, 1.5 * mm),
    ]


def title_card(title: str, subtitle: str, styles):
    card = Table(
        [[Paragraph(title, styles["title"])],
         [Paragraph(subtitle, styles["link"])]],
        colWidths=[A4[0] - 48 * mm],
        hAlign="CENTER",
    )
    card.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), colors.HexColor("#1C2E40")),
        ("BOX", (0, 0), (-1, -1), 0.7, BORDER),
        ("LINEABOVE", (0, 0), (-1, 0), 3.2, CYAN),
        ("LEFTPADDING", (0, 0), (-1, -1), 9 * mm),
        ("RIGHTPADDING", (0, 0), (-1, -1), 9 * mm),
        ("TOPPADDING", (0, 0), (-1, 0), 3.8 * mm),
        ("BOTTOMPADDING", (0, -1), (-1, -1), 1.5 * mm),
    ]))
    return card


def manual_story(source: Path, title: str, subtitle: str):
    styles = make_styles()
    lines = source.read_text(encoding="utf-8").splitlines()
    story = []
    if ICON_PATH.exists():
        image = Image(str(ICON_PATH), width=32 * mm, height=32 * mm)
        image.hAlign = "CENTER"
        story.extend([Spacer(1, 3 * mm), image, Spacer(1, 3.5 * mm)])
    story.extend([title_card(title, subtitle, styles), Spacer(1, 3 * mm)])

    index = 0
    while index < len(lines):
        line = lines[index].strip()
        if not line or line.startswith("# "):
            index += 1
            continue
        if line.startswith("[") and "](MANUAL" in line:
            story.append(Paragraph("Deutsch | English", styles["link"]))
            index += 1
            continue
        if image_match := re.fullmatch(r"!\[([^\]]*)\]\(([^)]+)\)", line):
            story.extend(screenshot_flowable(image_match.group(2), image_match.group(1), styles))
            index += 1
            continue
        if line.startswith("|"):
            raw_rows = []
            while index < len(lines) and lines[index].strip().startswith("|"):
                cells = [cell.strip() for cell in lines[index].strip().strip("|").split("|")]
                if not all(re.fullmatch(r":?-{3,}:?", cell) for cell in cells):
                    raw_rows.append(cells)
                index += 1
            story.extend(table_flowable(raw_rows, styles))
            continue
        if line.startswith("### "):
            story.append(Paragraph(paragraph_markup(line[4:]), styles["h2"]))
        elif line.startswith("## "):
            if line[3:] in {"Errors and safe next steps", "Fehler und sichere nächste Schritte"}:
                story.append(PageBreak())
            story.append(Paragraph(paragraph_markup(line[3:]), styles["h1"]))
        elif line.startswith("- "):
            story.append(Paragraph("• " + paragraph_markup(line[2:]), styles["bullet"]))
        elif match := re.match(r"(\d+)\.\s+(.*)", line):
            story.append(Paragraph(f"{match.group(1)}. " + paragraph_markup(match.group(2)), styles["number"]))
        else:
            story.append(Paragraph(paragraph_markup(line), styles["body"]))
        index += 1
    return story


def add_page_chrome(canvas, document):
    canvas.saveState()
    page_width, page_height = A4
    canvas.setFillColor(PAGE)
    canvas.rect(0, 0, page_width, page_height, fill=1, stroke=0)
    canvas.setFillColor(SIDEBAR)
    canvas.rect(0, 0, 23 * mm, page_height, fill=1, stroke=0)
    canvas.setFillColor(HEADER)
    canvas.rect(0, page_height - 13 * mm, page_width, 13 * mm, fill=1, stroke=0)
    canvas.setFillColor(CYAN)
    canvas.circle(page_width - 20 * mm, page_height - 6.5 * mm, 2.1 * mm, fill=1, stroke=0)
    canvas.setFillColor(SURFACE)
    canvas.roundRect(12 * mm, 15 * mm, page_width - 24 * mm, page_height - 34 * mm, 5 * mm, fill=1, stroke=0)
    canvas.setStrokeColor(BORDER)
    canvas.roundRect(12 * mm, 15 * mm, page_width - 24 * mm, page_height - 34 * mm, 5 * mm, fill=0, stroke=1)
    canvas.setFillColor(INK)
    canvas.setFont("Helvetica-Bold", 8.3)
    canvas.drawString(document.leftMargin, page_height - 8.4 * mm, "CODEXVAULT")
    canvas.setStrokeColor(BORDER)
    canvas.line(document.leftMargin, 12 * mm, page_width - document.rightMargin, 12 * mm)
    canvas.setFont("Helvetica", 8)
    canvas.setFillColor(MUTED)
    canvas.drawString(document.leftMargin, 7.8 * mm, "CodexVault")
    canvas.drawRightString(page_width - document.rightMargin, 7.8 * mm, f"Page {document.page}")
    canvas.restoreState()


def build_pdf(source_name: str, output_name: str, title: str, subtitle: str):
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    document = SimpleDocTemplate(
        str(OUTPUT_DIR / output_name), pagesize=A4,
        leftMargin=18 * mm, rightMargin=18 * mm, topMargin=17 * mm, bottomMargin=18 * mm,
        title=title, author="Schrotty74", subject="CodexVault user manual",
    )
    document.build(manual_story(SOURCE_DIR / source_name, title, subtitle), onFirstPage=add_page_chrome, onLaterPages=add_page_chrome)


if __name__ == "__main__":
    for source_name, output_name, title, subtitle in MANUALS:
        build_pdf(source_name, output_name, title, subtitle)
        print(OUTPUT_DIR / output_name)
