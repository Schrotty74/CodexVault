#!/usr/bin/env python3
"""Generate the public CodexVault manuals as visually checked PDF documents."""

from __future__ import annotations

import re
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.platypus import (
    Image,
    KeepTogether,
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
    ("MANUAL.en.txt", "CodexVault-Manual-EN.pdf", "CodexVault Manual"),
    ("MANUAL.de.txt", "CodexVault-Handbuch-DE.pdf", "CodexVault Handbuch"),
)


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
            fontSize=25, leading=30, textColor=colors.HexColor("#10213A"),
            alignment=TA_CENTER, spaceAfter=7 * mm,
        ),
        "h1": ParagraphStyle(
            "ManualHeading1", parent=styles["Heading1"], fontName="Helvetica-Bold",
            fontSize=17, leading=22, textColor=colors.HexColor("#10213A"),
            spaceBefore=7 * mm, spaceAfter=3 * mm,
        ),
        "h2": ParagraphStyle(
            "ManualHeading2", parent=styles["Heading2"], fontName="Helvetica-Bold",
            fontSize=13, leading=17, textColor=colors.HexColor("#1677D2"),
            spaceBefore=5 * mm, spaceAfter=2 * mm,
        ),
        "body": ParagraphStyle(
            "ManualBody", parent=styles["BodyText"], fontName="Helvetica",
            fontSize=9.8, leading=14, textColor=colors.HexColor("#202A35"),
            spaceAfter=2.2 * mm,
        ),
        "bullet": ParagraphStyle(
            "ManualBullet", parent=styles["BodyText"], fontName="Helvetica",
            fontSize=9.8, leading=14, leftIndent=5 * mm, firstLineIndent=-3.4 * mm,
            textColor=colors.HexColor("#202A35"), spaceAfter=1.3 * mm,
        ),
        "number": ParagraphStyle(
            "ManualNumber", parent=styles["BodyText"], fontName="Helvetica",
            fontSize=9.8, leading=14, leftIndent=7 * mm, firstLineIndent=-5 * mm,
            textColor=colors.HexColor("#202A35"), spaceAfter=1.5 * mm,
        ),
        "link": ParagraphStyle(
            "ManualLink", parent=styles["BodyText"], fontName="Helvetica-Oblique",
            fontSize=8.7, leading=12, textColor=colors.HexColor("#52616D"),
            alignment=TA_CENTER, spaceAfter=4 * mm,
        ),
    }


def table_flowable(rows: list[list[str]], styles):
    data = [[Paragraph(paragraph_markup(cell), styles["body"]) for cell in row] for row in rows]
    width = A4[0] - 36 * mm
    col_widths = [width / len(rows[0])] * len(rows[0])
    table = Table(data, colWidths=col_widths, repeatRows=1, hAlign="LEFT")
    table.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#DCEAF8")),
        ("TEXTCOLOR", (0, 0), (-1, 0), colors.HexColor("#10213A")),
        ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
        ("GRID", (0, 0), (-1, -1), 0.35, colors.HexColor("#B7C5D3")),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("LEFTPADDING", (0, 0), (-1, -1), 3.2 * mm),
        ("RIGHTPADDING", (0, 0), (-1, -1), 3.2 * mm),
        ("TOPPADDING", (0, 0), (-1, -1), 2.2 * mm),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 2.2 * mm),
        ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.HexColor("#F5F8FB")]),
    ]))
    return [Spacer(1, 1.5 * mm), table, Spacer(1, 2 * mm)]


def manual_story(source: Path, title: str):
    styles = make_styles()
    lines = source.read_text(encoding="utf-8").splitlines()
    story = []
    if ICON_PATH.exists():
        image = Image(str(ICON_PATH), width=31 * mm, height=31 * mm)
        image.hAlign = "CENTER"
        story.extend([Spacer(1, 2 * mm), image, Spacer(1, 3 * mm)])
    story.append(Paragraph(title, styles["title"]))

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
            story.append(Paragraph(paragraph_markup(line[3:]), styles["h1"]))
        elif line.startswith("- "):
            story.append(Paragraph("• " + paragraph_markup(line[2:]), styles["bullet"]))
        elif match := re.match(r"(\d+)\.\s+(.*)", line):
            story.append(Paragraph(f"{match.group(1)}. " + paragraph_markup(match.group(2)), styles["number"]))
        else:
            story.append(Paragraph(paragraph_markup(line), styles["body"]))
        index += 1
    return story


def add_page_number(canvas, document):
    canvas.saveState()
    canvas.setStrokeColor(colors.HexColor("#D5DEE7"))
    canvas.line(document.leftMargin, 12 * mm, A4[0] - document.rightMargin, 12 * mm)
    canvas.setFont("Helvetica", 8)
    canvas.setFillColor(colors.HexColor("#52616D"))
    canvas.drawString(document.leftMargin, 7.8 * mm, "CodexVault")
    canvas.drawRightString(A4[0] - document.rightMargin, 7.8 * mm, f"Page {document.page}")
    canvas.restoreState()


def build_pdf(source_name: str, output_name: str, title: str):
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    document = SimpleDocTemplate(
        str(OUTPUT_DIR / output_name), pagesize=A4,
        leftMargin=18 * mm, rightMargin=18 * mm, topMargin=17 * mm, bottomMargin=18 * mm,
        title=title, author="Schrotty74", subject="CodexVault user manual",
    )
    document.build(manual_story(SOURCE_DIR / source_name, title), onFirstPage=add_page_number, onLaterPages=add_page_number)


if __name__ == "__main__":
    for source_name, output_name, title in MANUALS:
        build_pdf(source_name, output_name, title)
        print(OUTPUT_DIR / output_name)
