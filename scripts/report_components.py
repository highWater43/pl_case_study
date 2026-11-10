from reportlab.lib import colors
from reportlab.lib.pagesizes import landscape
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.units import inch
from reportlab.platypus import Paragraph, Table, TableStyle


PAGE_SIZE = landscape((13.333 * inch, 7.5 * inch))
W, H = PAGE_SIZE

BLUE = colors.HexColor("#0068EF")
NAVY = colors.HexColor("#061E44")
INK = colors.HexColor("#172033")
MUTED = colors.HexColor("#5D687A")
LIGHT = colors.HexColor("#EEF5FF")
GRID = colors.HexColor("#D8E0EA")
GREEN = colors.HexColor("#0B8F60")
RED = colors.HexColor("#C93B3B")
WHITE = colors.white


styles = {
    "title": ParagraphStyle(
        "title", fontName="Helvetica-Bold", fontSize=27, leading=31, textColor=NAVY
    ),
    "body": ParagraphStyle(
        "body", fontName="Helvetica", fontSize=15, leading=20, textColor=INK
    ),
    "body_bold": ParagraphStyle(
        "body-bold", fontName="Helvetica-Bold", fontSize=15, leading=20, textColor=INK
    ),
    "small": ParagraphStyle(
        "small", fontName="Helvetica", fontSize=10.5, leading=14, textColor=MUTED
    ),
    "label": ParagraphStyle(
        "label", fontName="Helvetica-Bold", fontSize=10.5, leading=13, textColor=BLUE
    ),
    "quote": ParagraphStyle(
        "quote", fontName="Helvetica-Bold", fontSize=21, leading=27, textColor=NAVY
    ),
}


def para(c, text, x, top, width, height, style="body"):
    paragraph = Paragraph(text, styles[style])
    _, paragraph_height = paragraph.wrap(width, height)
    if paragraph_height > height + 0.1:
        raise ValueError(f"Text overflow: {text[:80]}")
    paragraph.drawOn(c, x, H - top - paragraph_height)
    return paragraph_height


def line(c, x1, y1, x2, y2, color=GRID, width=1):
    c.setStrokeColor(color)
    c.setLineWidth(width)
    c.line(x1, H - y1, x2, H - y2)


def footer(c, page):
    line(c, 48, 510, W - 48, 510, GRID, 0.6)
    c.setFont("Helvetica", 8.5)
    c.setFillColor(MUTED)
    c.drawString(
        48,
        16,
        "Synthetic case study. Results compare cities with the new design against cities that kept the old design.",
    )
    c.drawRightString(W - 48, 16, str(page))


def base(c, page, title, section=None):
    c.setFillColor(WHITE)
    c.rect(0, 0, W, H, fill=1, stroke=0)
    if section:
        para(c, section.upper(), 48, 23, 300, 18, "label")
    para(c, title, 48, 51, W - 230, 70, "title")
    line(c, 48, 125, W - 48, 125, BLUE, 2)
    footer(c, page)


def big_number(c, value, label, x, top, color=NAVY, width=360):
    c.setFillColor(color)
    c.setFont("Helvetica-Bold", 33)
    c.drawString(x, H - top - 31, value)
    para(c, label, x, top + 43, width, 75, "body")


def simple_bullet(c, text, x, top, width, color=BLUE):
    c.setFillColor(color)
    c.circle(x + 5, H - top - 8, 3.2, fill=1, stroke=0)
    return para(c, text, x + 18, top, width - 18, 60, "body")


def page_1(c):
    c.setFillColor(WHITE)
    c.rect(0, 0, W, H, fill=1, stroke=0)
    c.setFillColor(BLUE)
    c.rect(0, 0, 16, H, fill=1, stroke=0)
    para(
        c,
        "Should ForkDash expand the new AI-first support design?",
        62,
        112,
        690,
        100,
        "title",
    )
    para(
        c,
        "The test saved money, but many more customers failed to get help.",
        62,
        230,
        700,
        60,
        "quote",
    )
    line(c, 62, 330, 760, 330, BLUE, 2)
    para(c, "ForkDash synthetic case study", 62, 354, 420, 24, "body")
    para(c, "Prepared for a product analytics interview", 62, 386, 420, 24, "small")
    c.setFont("Helvetica", 8.5)
    c.setFillColor(MUTED)
    c.drawString(62, 24, "Synthetic data only.")


def page_3(c):
    base(c, 3, "What changed in the test", "The setup")
    para(c, "For six weeks, all eight cities used the old support design.", 62, 158, 560, 30, "body")
    line(c, 150, 245, 820, 245, GRID, 3)
    c.setFillColor(BLUE)
    c.circle(480, H - 245, 8, fill=1, stroke=0)
    para(c, "Weeks 1-6", 115, 210, 180, 25, "body_bold")
    para(c, "Week 7", 450, 210, 120, 25, "body_bold")
    para(c, "Weeks 7-12", 700, 210, 180, 25, "body_bold")
    para(c, "Four cities received the new design", 90, 285, 340, 25, "label")
    para(c, "AI chat became the main path. Phone access became harder to find.", 90, 315, 340, 55, "body")
    para(c, "Four cities kept the old design", 525, 285, 340, 25, "label")
    para(c, "Customers still had the original phone, chat, and email options.", 525, 315, 340, 55, "body")
    para(
        c,
        "We compare the before-and-after change in the new-design cities with the same change in the unchanged cities.",
        90,
        418,
        775,
        48,
        "body_bold",
    )


def page_5(c):
    base(c, 6, "How we decide whether the change worked", "What success means")
    para(c, "Main money result", 62, 160, 250, 24, "label")
    para(
        c,
        "Value left per order after support handling, refunds, credits, customer payment disputes, and fees",
        62,
        192,
        800,
        62,
        "quote",
    )
    line(c, 62, 285, 870, 285, GRID, 1)
    para(
        c,
        "The change can expand only if the money result improves and these customer results do not get meaningfully worse:",
        62,
        310,
        810,
        48,
        "body",
    )
    checks = [
        "Customers get their problem solved",
        "Customers do not abandon support or contact support again",
        "Customer payment disputes do not rise",
        "Customers continue ordering",
    ]
    for index, text in enumerate(checks):
        x = 75 if index % 2 == 0 else 500
        top = 375 if index < 2 else 430
        simple_bullet(c, text, x, top, 360)


def page_order_example(c):
    base(c, 7, "Example: how a $50 order becomes $3.45 of value left", "One completed order")
    para(c, "The case assumes 12% of the order value remains before support problems.", 62, 153, 800, 30, "body")

    cell = ParagraphStyle("order-example-cell", fontName="Helvetica", fontSize=13, leading=16, textColor=INK)
    cell_bold = ParagraphStyle("order-example-bold", fontName="Helvetica-Bold", fontSize=13, leading=16, textColor=INK)
    header = ParagraphStyle("order-example-header", fontName="Helvetica-Bold", fontSize=13, leading=16, textColor=WHITE)
    rows = [
        [Paragraph("Component", header), Paragraph("Amount", header)],
        [Paragraph("Order value", cell), Paragraph("$50.00", cell)],
        [Paragraph("Starting value at 12%", cell), Paragraph("$6.00", cell)],
        [Paragraph("Support handling", cell), Paragraph("-$0.55", cell)],
        [Paragraph("Refund", cell), Paragraph("-$2.00", cell)],
        [Paragraph("Customer credit", cell), Paragraph("$0.00", cell)],
        [Paragraph("Disputed payment", cell), Paragraph("$0.00", cell)],
        [Paragraph("Dispute fee", cell), Paragraph("$0.00", cell)],
        [Paragraph("Value left", cell_bold), Paragraph("$3.45", cell_bold)],
    ]
    table = Table(rows, colWidths=[570, 190], rowHeights=[32] + [26] * 8)
    table.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, 0), NAVY),
                ("BACKGROUND", (0, -1), (-1, -1), LIGHT),
                ("GRID", (0, 0), (-1, -1), 0.6, GRID),
                ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
                ("LEFTPADDING", (0, 0), (-1, -1), 10),
                ("RIGHTPADDING", (0, 0), (-1, -1), 10),
            ]
        )
    )
    _, table_height = table.wrap(760, H)
    table.drawOn(c, 90, H - 198 - table_height)

    para(c, "$6.00 - $0.55 - $2.00 = $3.45", 90, 450, 400, 28, "body_bold")
    para(
        c,
        "The $50 order value is not added again. The $6 starting value is already 12% of the $50 order.",
        90,
        480,
        760,
        25,
        "small",
    )
