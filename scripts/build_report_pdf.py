#!/usr/bin/env python3

import csv
import importlib.util
from pathlib import Path

from reportlab.lib.styles import ParagraphStyle
from reportlab.pdfgen import canvas
from reportlab.platypus import Paragraph, Table, TableStyle


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "output/pdf/forkdash-case-study-report.pdf"

spec = importlib.util.spec_from_file_location(
    "base_report", ROOT / "scripts/report_components.py"
)
base_report = importlib.util.module_from_spec(spec)
spec.loader.exec_module(base_report)


def read_export(name):
    with (ROOT / "data/exports" / name).open(newline="") as handle:
        return list(csv.DictReader(handle))


mapping_rows = read_export("source_mapping_summary.csv")
ai_rows = read_export("ai_issue_scorecard.csv")
sim_rows = read_export("simulation_metric_results.csv")
relationship_rows = read_export("metric_relationships.csv")


def mapping_count(source_name, status):
    return int(
        next(
            row["record_count"]
            for row in mapping_rows
            if row["source_name"] == source_name and row["mapping_status"] == status
        )
    )


def sim_metric(metric_name, field="simulated_treated_post"):
    return float(
        next(
            row[field]
            for row in sim_rows
            if row["scenario_id"] == "FAST_HELP_EXPECTED"
            and row["metric_name"] == metric_name
        )
    )


def relationship_value(name):
    return float(
        next(
            row["pearson_correlation"]
            for row in relationship_rows
            if row["relationship"] == name
        )
    )


CURRENT_PAGE = 1
SECTION_BY_PAGE = {
    2: "1. Executive summary",
    3: "2. Data trust",
    4: "2. Data trust",
    5: "2. Data trust",
    6: "3. Metric framework",
    7: "3. Metric framework",
    8: "3. Metric framework",
    9: "4. Relationships between metrics",
    10: "4. Relationships between metrics",
    11: "5. Diagnosis",
    12: "5. Diagnosis",
    13: "6. Recommendations",
    14: "6. Recommendations",
    15: "6. Recommendations",
    16: "6. Recommendations",
    17: "7. Operating approach",
    18: "7. Operating approach",
    19: "8. AI usage log",
}

original_base = base_report.base
original_footer = base_report.footer


def v2_footer(c, _page):
    original_footer(c, CURRENT_PAGE)


def v2_base(c, _page, title, _section=None):
    original_base(c, CURRENT_PAGE, title, SECTION_BY_PAGE.get(CURRENT_PAGE))


base_report.footer = v2_footer
base_report.base = v2_base


def page_executive_summary(c):
    base_report.base(c, 0, "Expansion should wait for a redesigned handoff")
    base_report.para(
        c,
        "Keep AI for customer problems it resolves reliably. Give customers a clear path to a person when AI cannot solve the problem.",
        62,
        155,
        810,
        72,
        "quote",
    )
    base_report.line(c, 62, 250, 898, 250, base_report.GRID, 1)
    base_report.para(
        c,
        "Direct handling cost fell, but the customer guardrails failed.",
        62,
        275,
        800,
        28,
        "body_bold",
    )
    base_report.big_number(
        c,
        "16 fewer",
        "contacts stayed resolved out of every 100",
        75,
        315,
        base_report.RED,
        340,
    )
    base_report.big_number(
        c,
        "14 more",
        "customers abandoned support out of every 100",
        530,
        315,
        base_report.RED,
        350,
    )
    c.setFillColor(base_report.LIGHT)
    c.roundRect(62, base_report.H - 500, 808, 62, 10, fill=1, stroke=0)
    base_report.para(
        c,
        "Approach: identify which problems AI resolves, restore easy human escalation, simulate the likely effect, and prove the redesign in a controlled test.",
        82,
        450,
        765,
        40,
        "body_bold",
    )


def page_two_by_two_design(c):
    base_report.base(c, 0, "The comparison keeps the national campaign in both groups")
    base_report.para(
        c,
        "Four cities changed support in week 7. Four cities kept the old support design. A national free-delivery campaign began in week 8 and affected both groups.",
        62,
        150,
        830,
        48,
        "body",
    )

    header = ParagraphStyle(
        "design-header",
        fontName="Helvetica-Bold",
        fontSize=12,
        leading=15,
        textColor=base_report.WHITE,
    )
    cell = ParagraphStyle(
        "design-cell",
        fontName="Helvetica",
        fontSize=11.5,
        leading=15,
        textColor=base_report.INK,
    )
    cell_bold = ParagraphStyle(
        "design-cell-bold",
        fontName="Helvetica-Bold",
        fontSize=11.5,
        leading=15,
        textColor=base_report.INK,
    )
    rows = [
        [
            Paragraph("City group", header),
            Paragraph("Before week 7<br/>Weeks 1 to 6", header),
            Paragraph("After week 7<br/>Weeks 7 to 12", header),
        ],
        [
            Paragraph("4 cities where support changed", cell_bold),
            Paragraph("Old support design<br/>No campaign", cell),
            Paragraph("AI-first support from week 7<br/>Campaign from week 8", cell),
        ],
        [
            Paragraph("4 cities where support did not change", cell_bold),
            Paragraph("Old support design<br/>No campaign", cell),
            Paragraph("Old support design<br/>Campaign from week 8", cell),
        ],
    ]
    table = Table(rows, colWidths=[245, 260, 295], rowHeights=[48, 76, 76])
    table.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), base_report.NAVY),
        ("BACKGROUND", (0, 1), (0, -1), base_report.LIGHT),
        ("GRID", (0, 0), (-1, -1), 0.8, base_report.GRID),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("LEFTPADDING", (0, 0), (-1, -1), 12),
        ("RIGHTPADDING", (0, 0), (-1, -1), 12),
    ]))
    _, table_h = table.wrap(800, base_report.H)
    table.drawOn(c, 80, base_report.H - 220 - table_h)

    c.setFillColor(base_report.LIGHT)
    c.roundRect(62, base_report.H - 500, 808, 80, 10, fill=1, stroke=0)
    base_report.para(c, "The calculation for every measure", 82, 430, 310, 22, "label")
    base_report.para(
        c,
        "Change in the four cities where support changed, minus the change in the four cities where support did not change.",
        82,
        458,
        760,
        42,
        "body_bold",
    )



def page_data_trust(c):
    base_report.base(c, 0, "What connected cleanly and what remains uncertain")

    exact_support = mapping_count("support contacts", "exact order match")
    inferred_support = mapping_count("support contacts", "customer and time match")
    unmatched_support = mapping_count("support contacts", "not linked to an order")
    mapped_finance = mapping_count("finance ledger", "exact order match")

    base_report.big_number(
        c,
        "99.1%",
        "of support contacts connect to an order",
        62,
        154,
        base_report.GREEN,
        350,
    )
    base_report.big_number(
        c,
        f"{mapped_finance:,}",
        "finance rows all connect to an order",
        520,
        154,
        base_report.GREEN,
        350,
    )
    base_report.line(c, 62, 285, 875, 285, base_report.GRID, 1)

    base_report.para(c, "Where the connection is less certain", 62, 310, 380, 24, "label")
    gaps = [
        f"{inferred_support:,} support contacts needed customer-and-time matching instead of an order ID.",
        f"{unmatched_support:,} contacts could not reach an order, so their handling cost cannot connect to refunds or payment disputes.",
        "Recent orders need 28 to 30 days before payment-dispute results are complete.",
        "The source files do not contain agent staffing, wage, or queue-capacity cost.",
    ]
    top = 348
    for text in gaps:
        used = base_report.simple_bullet(c, text, 70, top, 800)
        top += used + 14

    base_report.para(
        c,
        f"Exact support matches: {exact_support:,}. Indirect matches remain visible and can be removed in a sensitivity check.",
        62,
        475,
        810,
        28,
        "small",
    )


def page_team_metrics(c):
    base_report.base(c, 0, "One shared result, with one important metric for each team")

    c.setFillColor(base_report.LIGHT)
    c.roundRect(62, base_report.H - 226, 808, 76, 10, fill=1, stroke=0)
    base_report.para(c, "SHARED NORTH STAR", 82, 164, 210, 18, "label")
    base_report.para(
        c,
        "Value left per order after support handling, refunds, credits, payment disputes, fees, and real staffing cost",
        82,
        188,
        755,
        38,
        "body_bold",
    )

    base_report.para(c, "Teams that shape the customer experience", 62, 252, 370, 20, "label")
    base_report.para(c, "Teams that protect money and measurement", 500, 252, 370, 20, "label")
    base_report.line(c, 466, 250, 466, 490, base_report.GRID, 1)

    left_rows = [
        ("AI Product | Verified AI resolution", "Which problems did AI solve without the customer returning?"),
        ("Customer Care | Seven-day resolution", "Did the customer's problem stay solved for seven days?"),
        ("Care Operations | Human response time", "Did a customer who needed a person reach one quickly?"),
        ("COO | Handling cost per order", "Did direct support become cheaper without hiding customer harm?"),
    ]
    right_rows = [
        ("Finance | Payment disputes", "Did more customers ask their bank to reverse an order charge?"),
        ("CX Insights | Satisfaction", "Were survey respondents satisfied, and who answered the survey?"),
        ("Loyalty | 28-day reorder", "Did customers with a support problem place another order?"),
        ("Data | Source connection quality", "Can support and finance records be linked to the correct order?"),
    ]

    for rows, x in ((left_rows, 62), (right_rows, 500)):
        for index, (metric, question) in enumerate(rows):
            top = 286 + index * 52
            base_report.para(c, metric, x, top, 370, 22, "body_bold")
            base_report.para(c, question, x, top + 23, 370, 28, "small")

    c.setFont("Helvetica", 7.4)
    c.setFillColor(base_report.MUTED)
    c.drawString(48, 38, "Current source data does not contain staffing dollars. The live experiment must add them before the North Star is final.")


def relationship_row(c, left_label, score, right_label, explanation, top, direction):
    c.setFillColor(base_report.LIGHT)
    c.roundRect(62, base_report.H - top - 104, 808, 104, 10, fill=1, stroke=0)
    base_report.para(c, left_label, 84, top + 17, 255, 44, "body_bold")
    base_report.para(c, right_label, 620, top + 17, 225, 44, "body_bold")
    c.setFont("Helvetica-Bold", 25)
    c.setFillColor(base_report.NAVY)
    c.drawCentredString(480, base_report.H - top - 42, f"{score:+.2f}")
    base_report.para(c, direction, 397, top + 52, 166, 20, "label")
    base_report.para(c, explanation, 84, top + 73, 760, 25, "small")


def page_cost_relationships(c):
    base_report.base(c, 0, "Lower handling cost moved with more abandonment and disputes")
    base_report.para(
        c,
        "These relationships compare the metrics across all 96 city-weeks in the synthetic case data.",
        62,
        150,
        820,
        36,
        "body",
    )
    relationship_row(
        c,
        "Direct handling cost per order",
        relationship_value("handling_cost_per_order vs abandonment_rate"),
        "Customers abandoning support",
        "When handling cost was lower, more customers tended to leave before their problem reached a successful end.",
        205,
        "OPPOSITE MOVEMENT",
    )
    relationship_row(
        c,
        "Direct handling cost per order",
        relationship_value("handling_cost_per_order vs chargebacks_per_1000_orders"),
        "Customer payment disputes",
        "Lower-cost weeks also tended to have more payment disputes after the order.",
        335,
        "OPPOSITE MOVEMENT",
    )
    base_report.para(
        c,
        "How to read this: the relationship score runs from -1 to +1. A negative score means the metrics moved in opposite directions. This pattern does not prove that lower cost caused either customer outcome.",
        62,
        465,
        820,
        38,
        "small",
    )


def page_experience_relationships(c):
    base_report.base(c, 0, "Resolution, satisfaction, repeat support, and disputes moved together")
    base_report.para(
        c,
        "These relationships use the same 96 city-weeks and connect the support experience with later customer outcomes.",
        62,
        150,
        820,
        36,
        "body",
    )
    relationship_row(
        c,
        "Problems successfully resolved",
        relationship_value("verified_resolution_rate vs average_csat"),
        "Customer satisfaction score",
        "Weeks with more verified resolutions tended to have higher satisfaction among customers who answered the survey.",
        205,
        "SAME DIRECTION",
    )
    relationship_row(
        c,
        "Orders with repeat support",
        relationship_value("repeat_contact_rate vs chargebacks_per_1000_orders"),
        "Customer payment disputes",
        "Weeks with more repeat support also tended to have more payment disputes.",
        335,
        "SAME DIRECTION",
    )
    base_report.para(
        c,
        "How to read this: the relationship score runs from -1 to +1. A positive score means the metrics moved in the same direction. Satisfaction includes respondents only. Issue severity and delayed finance posting may influence both metrics.",
        62,
        465,
        820,
        38,
        "small",
    )


def page_diagnosis(c):
    base_report.base(c, 0, "What most likely happened after week 7")
    base_report.para(c, "Our explanation", 62, 155, 300, 22, "label")
    base_report.para(
        c,
        "Human help became harder to reach. Some customers could not solve their problem in AI, so they left support, came back later, or disputed the payment.",
        62,
        195,
        380,
        135,
        "quote",
    )
    base_report.para(
        c,
        "Why we think this: the problems began after the support change and were worse in the four cities that changed.",
        62,
        350,
        380,
        70,
        "body",
    )

    base_report.para(c, "Why we are not certain", 500, 155, 350, 22, "label")
    alternatives = [
        "The changed cities may have received different or harder customer problems.",
        "The national promotion may have affected the city groups differently.",
        "The cities were not assigned at random.",
        "Recent survey and payment-dispute data may be incomplete.",
    ]
    top = 195
    for text in alternatives:
        used = base_report.simple_bullet(c, text, 500, top, 365)
        top += used + 18

    c.setFillColor(base_report.LIGHT)
    c.roundRect(62, base_report.H - 500, 808, 72, 10, fill=1, stroke=0)
    base_report.para(c, "Conclusion", 82, 436, 250, 20, "label")
    base_report.para(
        c,
        "The support change is the most likely explanation, but only a randomized test can show whether it caused the customer problems.",
        82,
        459,
        760,
        42,
        "body_bold",
    )


def page_ai_close_look(c):
    base_report.base(c, 0, "A chat can end in AI while the customer still needs help")
    base_report.para(
        c,
        "The largest AI case types show a wide gap between ending without an agent and staying resolved for seven days.",
        62,
        150,
        820,
        44,
        "body",
    )

    selected = []
    for issue in ["late_order", "cancelled", "missing_item", "wrong_item"]:
        row = next(
            item
            for item in ai_rows
            if item["treatment_group"] == "treatment"
            and item["post_period"].lower() in {"t", "true", "1"}
            and item["issue_type"] == issue
            and item["issue_severity"] in {"medium", "high"}
        )
        selected.append(row)

    display_names = {
        "late_order": "Late order",
        "cancelled": "Cancellation",
        "missing_item": "Missing item",
        "wrong_item": "Wrong item",
    }
    header = ParagraphStyle(
        "ai-header",
        fontName="Helvetica-Bold",
        fontSize=12,
        leading=15,
        textColor=base_report.WHITE,
    )
    cell = ParagraphStyle(
        "ai-cell",
        fontName="Helvetica",
        fontSize=12,
        leading=15,
        textColor=base_report.INK,
    )
    cell_bold = ParagraphStyle(
        "ai-cell-bold",
        fontName="Helvetica-Bold",
        fontSize=12,
        leading=15,
        textColor=base_report.INK,
    )
    rows = [[
        Paragraph("Customer problem", header),
        Paragraph("AI chats", header),
        Paragraph("Ended without an agent", header),
        Paragraph("Stayed resolved", header),
        Paragraph("Contacted again", header),
    ]]
    for row in selected:
        rows.append([
            Paragraph(display_names[row["issue_type"]], cell_bold),
            Paragraph(f"{int(row['ai_starts']):,}", cell),
            Paragraph(f"{round(100 * float(row['technical_containment_rate']))} out of 100", cell),
            Paragraph(f"{round(100 * float(row['verified_containment_rate']))} out of 100", cell),
            Paragraph(f"{round(100 * float(row['repeat_contact_rate_7d']))} out of 100", cell),
        ])

    table = Table(rows, colWidths=[190, 100, 185, 170, 155], rowHeights=[34] + [38] * 4)
    table.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), base_report.NAVY),
        ("BACKGROUND", (0, 1), (0, -1), base_report.LIGHT),
        ("GRID", (0, 0), (-1, -1), 0.7, base_report.GRID),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("LEFTPADDING", (0, 0), (-1, -1), 9),
        ("RIGHTPADDING", (0, 0), (-1, -1), 9),
    ]))
    _, table_h = table.wrap(800, base_report.H)
    table.drawOn(c, 80, base_report.H - 205 - table_h)

    base_report.para(
        c,
        "Next analysis: identify the problem types AI resolves reliably and send higher-risk cases to a person sooner.",
        80,
        405,
        800,
        42,
        "body_bold",
    )
    base_report.para(
        c,
        "Stayed resolved means the contact ended as resolved and the customer did not contact support again for that order within seven days.",
        80,
        465,
        800,
        28,
        "small",
    )


def page_simulation(c):
    base_report.base(c, 0, "Same-data simulation improves the gaps but does not close them")
    base_report.para(
        c,
        "The simulation copies the same changed-city records after week 7 and substitutes outcomes from comparable faster cases in the same database. Before-period and unchanged-city records stay observed.",
        62,
        150,
        835,
        56,
        "body",
    )

    rows_data = [
        (
            "Resolution time after AI needed a person",
            f"{sim_metric('completed_resolution_time_minutes', 'observed_did_effect'):.1f} min longer",
            f"{sim_metric('completed_resolution_time_minutes', 'simulated_did_effect'):.1f} min longer",
        ),
        (
            "Problems successfully resolved",
            f"{abs(round(100 * sim_metric('verified_resolution_rate', 'observed_did_effect')))} fewer per 100",
            f"{abs(round(100 * sim_metric('verified_resolution_rate', 'simulated_did_effect')))} fewer per 100",
        ),
        (
            "Customers abandoning support",
            f"{round(100 * sim_metric('abandonment_rate', 'observed_did_effect'))} more per 100",
            f"{round(100 * sim_metric('abandonment_rate', 'simulated_did_effect'))} more per 100",
        ),
        (
            "Orders with repeat support",
            f"{round(100 * sim_metric('repeat_contact_rate', 'observed_did_effect'))} more per 100",
            f"{round(100 * sim_metric('repeat_contact_rate', 'simulated_did_effect'))} more per 100",
        ),
        (
            "Customer payment disputes",
            f"{sim_metric('chargebacks_per_1000_orders', 'observed_did_effect'):.1f} more per 1,000",
            f"{sim_metric('chargebacks_per_1000_orders', 'simulated_did_effect'):.1f} more per 1,000",
        ),
        (
            "Cost per successful resolution",
            f"${sim_metric('total_cost_per_verified_resolution', 'observed_did_effect'):.2f} more",
            f"${sim_metric('total_cost_per_verified_resolution', 'simulated_did_effect'):.2f} more",
        ),
    ]
    header = ParagraphStyle("sim-header", fontName="Helvetica-Bold", fontSize=11.8, leading=14, textColor=base_report.WHITE)
    cell = ParagraphStyle("sim-cell", fontName="Helvetica", fontSize=11.8, leading=14, textColor=base_report.INK)
    cell_bold = ParagraphStyle("sim-bold", fontName="Helvetica-Bold", fontSize=11.8, leading=14, textColor=base_report.INK)
    rows = [[Paragraph("Measure", header), Paragraph("Observed gap", header), Paragraph("Simulated gap", header)]]
    for label, current, simulated in rows_data:
        rows.append([Paragraph(label, cell_bold), Paragraph(current, cell), Paragraph(simulated, cell)])
    table = Table(rows, colWidths=[340, 225, 235], rowHeights=[33] + [32] * 6)
    table.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), base_report.NAVY),
        ("BACKGROUND", (0, 1), (0, -1), base_report.LIGHT),
        ("GRID", (0, 0), (-1, -1), 0.7, base_report.GRID),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("LEFTPADDING", (0, 0), (-1, -1), 10),
        ("RIGHTPADDING", (0, 0), (-1, -1), 10),
    ]))
    _, table_h = table.wrap(800, base_report.H)
    table.drawOn(c, 80, base_report.H - 210 - table_h)

    added_hours = sim_metric("additional_human_hours")
    c.setFillColor(base_report.LIGHT)
    c.roundRect(62, base_report.H - 500, 808, 59, 10, fill=1, stroke=0)
    base_report.para(c, "Additional human time", 82, 447, 330, 18, "label")
    base_report.para(c, f"About {added_hours:.0f} hours across six weeks", 82, 469, 330, 29, "body_bold")
    base_report.para(c, "Decision", 480, 447, 350, 18, "label")
    base_report.para(c, "Better, but the customer guardrails still fail.", 480, 469, 350, 29, "body_bold")

    c.setFont("Helvetica", 7.6)
    c.setFillColor(base_report.MUTED)
    c.drawString(48, 38, "Simulated, not observed. The same 2-by-2 calculation is used. Staffing dollars are unavailable and excluded.")


def signal_explanation(c, number, title, data_text, why_text, top):
    base_report.para(c, f"{number}. {title}", 62, top, 205, 58, "body_bold")
    base_report.para(c, data_text, 285, top, 255, 62, "body")
    base_report.para(c, why_text, 565, top, 305, 62, "body")
    if top < 360:
        base_report.line(c, 62, top + 66, 870, top + 66, base_report.GRID, 0.7)


def page_targeted_simulation_inputs(c):
    base_report.base(c, 0, "Signals 1-3 describe the customer problem and order")
    base_report.para(
        c,
        "The simulation groups similar ForkDash support cases before estimating the result of faster human help.",
        62,
        150,
        825,
        38,
        "body",
    )
    base_report.para(c, "Signal", 62, 205, 205, 20, "label")
    base_report.para(c, "Data point", 285, 205, 255, 20, "label")
    base_report.para(c, "Why it matters", 565, 205, 305, 20, "label")
    signal_explanation(
        c,
        1,
        "Customer problem",
        "Support problem type, such as late order, cancellation, missing item, or wrong item.",
        "AI may solve a delivery-status question but struggle with a cancellation or missing item.",
        238,
    )
    signal_explanation(
        c,
        2,
        "Problem severity",
        "Low, medium, or high severity on the support case.",
        "The same problem can require different urgency. More serious cases may need a person sooner.",
        315,
    )
    signal_explanation(
        c,
        3,
        "Order value",
        "The original amount of the order.",
        "A refund or dispute on a larger order puts more value at risk. Order value never controls access by itself.",
        392,
    )
    c.setFont("Helvetica", 7.6)
    c.setFillColor(base_report.MUTED)
    c.drawString(48, 38, "Proposed next simulation, not an observed result. These signals group similar cases before estimating outcomes.")


def page_targeted_simulation_risk(c):
    base_report.base(c, 0, "Signals 4-6 describe financial risk and AI success")
    base_report.para(
        c,
        "These signals show what ForkDash may lose and whether AI has kept similar problems solved.",
        62,
        150,
        825,
        38,
        "body",
    )
    base_report.para(c, "Signal", 62, 205, 205, 20, "label")
    base_report.para(c, "Data point", 285, 205, 255, 20, "label")
    base_report.para(c, "Why it matters", 565, 205, 305, 20, "label")
    signal_explanation(
        c,
        4,
        "Refund risk",
        "Whether similar cases received a refund or credit, plus the average amount.",
        "Faster help may solve the problem before ForkDash needs to issue a refund.",
        238,
    )
    signal_explanation(
        c,
        5,
        "Payment-dispute risk",
        "Whether similar orders were disputed, the disputed amount, and the dispute fee.",
        "Fast human help may prevent the customer from asking the bank to reverse the payment.",
        305,
    )
    signal_explanation(
        c,
        6,
        "How often AI solved it before",
        "AI-only cases that stayed resolved with no repeat support for the same order within seven days.",
        "Keep cases in AI when they stay solved. Send customers to a person sooner when they often return.",
        372,
    )
    c.setFillColor(base_report.LIGHT)
    c.roundRect(62, base_report.H - 488, 808, 54, 10, fill=1, stroke=0)
    base_report.para(
        c,
        "Recommend faster human help only when more problems stay resolved and value left rises after real staffing cost.",
        82,
        440,
        760,
        42,
        "body_bold",
    )
    c.setFont("Helvetica", 7.6)
    c.setFillColor(base_report.MUTED)
    c.drawString(48, 38, "Proposed next simulation, not an observed result. Staffing cost and support-page exit data are still required.")


def page_recommendation_options(c):
    base_report.base(c, 0, "Three choices and why the redesign is recommended")
    base_report.para(
        c,
        "The current AI-first design should not expand unchanged. All three choices enter the controlled test on the next slide.",
        62,
        150,
        825,
        44,
        "body",
    )

    choices = [
        (
            "1. Continue the current design",
            "POSITION: DO NOT CHOOSE",
            "Benefit: keeps the largest visible handling savings.",
            "Risk: the current resolution and abandonment gaps continue.",
            False,
        ),
        (
            "2. Restore the original support design",
            "POSITION: SAFETY FALLBACK",
            "Benefit: quickly restores familiar access to a person.",
            "Risk: gives up AI that works for routine problems.",
            False,
        ),
        (
            "3. Keep AI and restore easy human help",
            "POSITION: RECOMMENDED",
            "Benefit: keeps reliable AI while repairing access to help.",
            "Risk: needs more human capacity and may still miss guardrails.",
            True,
        ),
    ]
    top = 215
    for title, position, benefit, risk, highlight in choices:
        if highlight:
            c.setFillColor(base_report.LIGHT)
            c.roundRect(62, base_report.H - top - 82, 808, 82, 8, fill=1, stroke=0)
        base_report.para(c, title, 78, top + 8, 280, 44, "body_bold")
        base_report.para(c, position, 78, top + 51, 280, 18, "label")
        base_report.para(c, benefit, 375, top + 8, 470, 32, "body")
        base_report.para(c, risk, 375, top + 45, 470, 32, "body")
        if not highlight:
            base_report.line(c, 62, top + 82, 870, top + 82, base_report.GRID, 0.7)
        top += 88

    base_report.para(
        c,
        "Before expansion: measure staffing cost and support-page exits, and wait for payment disputes to mature.",
        62,
        481,
        810,
        22,
        "small",
    )


def page_next_test(c):
    base_report.base(c, 0, "A three-group test can prove whether the redesign works")
    base_report.para(
        c,
        "Randomly assign eligible support sessions within the same cities so promotions and city differences affect every group at the same time.",
        62,
        150,
        830,
        48,
        "body",
    )

    header = ParagraphStyle("test-header", fontName="Helvetica-Bold", fontSize=12, leading=15, textColor=base_report.WHITE)
    cell = ParagraphStyle("test-cell", fontName="Helvetica", fontSize=12, leading=15, textColor=base_report.INK)
    rows = [
        [Paragraph("Group", header), Paragraph("Customer experience", header), Paragraph("What it answers", header)],
        [Paragraph("Original design", cell), Paragraph("Original phone, chat, and email access", cell), Paragraph("What happens without AI-first routing", cell)],
        [Paragraph("Current AI-first", cell), Paragraph("AI default with difficult human access", cell), Paragraph("Whether the current program remains acceptable", cell)],
        [Paragraph("Redesigned", cell), Paragraph("AI with easy escalation and a five-minute target", cell), Paragraph("Whether faster human help repairs the program", cell)],
    ]
    table = Table(rows, colWidths=[175, 325, 300], rowHeights=[30, 40, 40, 40])
    table.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), base_report.NAVY),
        ("BACKGROUND", (0, 1), (0, -1), base_report.LIGHT),
        ("GRID", (0, 0), (-1, -1), 0.7, base_report.GRID),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("LEFTPADDING", (0, 0), (-1, -1), 9),
        ("RIGHTPADDING", (0, 0), (-1, -1), 9),
    ]))
    _, table_h = table.wrap(800, base_report.H)
    table.drawOn(c, 80, base_report.H - 205 - table_h)

    base_report.para(c, "The redesigned group passes only when:", 62, 370, 380, 24, "body_bold")
    rules = [
        "A person responds within five minutes.",
        "Successful resolution stays within 3 out of 100 of the original design.",
        "Abandonment and repeat support stay within 2 out of 100.",
        "Mature payment disputes do not rise, and value left improves by at least 5 cents per order.",
    ]
    rule_cell = ParagraphStyle("rule-cell", fontName="Helvetica", fontSize=11.5, leading=14, textColor=base_report.INK)
    rule_rows = [
        [Paragraph(f"<b>1.</b> {rules[0]}", rule_cell), Paragraph(f"<b>2.</b> {rules[1]}", rule_cell)],
        [Paragraph(f"<b>3.</b> {rules[2]}", rule_cell), Paragraph(f"<b>4.</b> {rules[3]}", rule_cell)],
    ]
    rule_table = Table(rule_rows, colWidths=[390, 390], rowHeights=[40, 40])
    rule_table.setStyle(TableStyle([
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("LEFTPADDING", (0, 0), (-1, -1), 6),
        ("RIGHTPADDING", (0, 0), (-1, -1), 14),
        ("TOPPADDING", (0, 0), (-1, -1), 4),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
    ]))
    _, rule_h = rule_table.wrap(780, base_report.H)
    rule_table.drawOn(c, 80, base_report.H - 400 - rule_h)

    c.setFont("Helvetica", 7.4)
    c.setFillColor(base_report.MUTED)
    c.drawString(48, 38, "Add support-page view, human-request, and exit events so customers who leave before starting a contact are counted. Keep observed and simulated data separately labeled.")


def page_operating_monitoring(c):
    base_report.base(c, 0, "Reliable measurement and automated monitoring")
    base_report.para(c, "Repeatable data process", 62, 155, 330, 22, "label")
    process = [
        "Preserve the original order, support, and finance files.",
        "Standardize fields and labels in stg_ models.",
        "Connect contacts and costs to orders in int_ models.",
        "Publish governed fct_ and dim_ models for every result.",
    ]
    top = 195
    for text in process:
        used = base_report.simple_bullet(c, text, 62, top, 365)
        top += used + 13

    base_report.para(c, "Automated checks after every load", 500, 155, 350, 22, "label")
    checks = [
        "Data checks: did every file arrive, and did each support contact and cost link to the right order?",
        "Customer journey: did AI receive different problems? Did people wait longer for a person or a solution?",
        "Safety limits: did unresolved cases, repeat contacts, payment disputes, or value left become unacceptable?",
    ]
    top = 195
    for text in checks:
        used = base_report.simple_bullet(c, text, 500, top, 365)
        top += used + 13

    c.setFillColor(base_report.LIGHT)
    c.roundRect(62, base_report.H - 500, 808, 76, 10, fill=1, stroke=0)
    base_report.para(c, "Weekly action", 82, 433, 180, 20, "label")
    base_report.para(
        c,
        "Continue, investigate, or pause the redesigned experience. AI may summarize unusual issue types and sample chats, but people set the thresholds and approve expansion.",
        82,
        457,
        760,
        40,
        "body_bold",
    )


def page_ai_usage(c):
    base_report.base(c, 0, "AI helped me expand my ideas, and I tested each one against the data")

    header = ParagraphStyle(
        "ai-usage-header",
        fontName="Helvetica-Bold",
        fontSize=10.5,
        leading=12.5,
        textColor=base_report.WHITE,
    )
    cell = ParagraphStyle(
        "ai-usage-cell",
        fontName="Helvetica",
        fontSize=10.5,
        leading=12.5,
        textColor=base_report.INK,
    )
    rows = [
        [Paragraph("My idea", header), Paragraph("How AI helped", header), Paragraph("How I tested it", header)],
        [
            Paragraph("Defined the 2-by-2 comparison", cell),
            Paragraph("Turned it into SQL and a visual", cell),
            Paragraph("Confirmed all eight cities, all 12 weeks, and the campaign timing were included in both groups", cell),
        ],
        [
            Paragraph("Proposed value left per order", cell),
            Paragraph("Broke it into traceable financial components", cell),
            Paragraph("Reconciled each component to order, support, and finance data and checked that costs were not counted twice", cell),
        ],
        [
            Paragraph("Proposed the faster human help simulation", cell),
            Paragraph("Connected it to customer and financial outcomes", cell),
            Paragraph("Changed only eligible records after week 7, kept the original data fixed, and reran the same 2-by-2 comparison", cell),
        ],
        [
            Paragraph("Chose the targeted simulation signals", cell),
            Paragraph("Helped define the required data and calculations", cell),
            Paragraph("Confirmed which signals exist in the source data and disclosed missing staffing and customer-exit data", cell),
        ],
        [
            Paragraph("Set the recommendation direction", cell),
            Paragraph("Tested alternatives, risks, and competing explanations", cell),
            Paragraph("Required value left to improve while resolution, abandonment, disputes, and repeat ordering stayed within acceptable limits", cell),
        ],
    ]
    table = Table(
        rows,
        colWidths=[210, 250, 340],
        rowHeights=[30, 46, 52, 58, 52, 58],
    )
    table.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, 0), base_report.NAVY),
                ("BACKGROUND", (0, 1), (0, -1), base_report.LIGHT),
                ("GRID", (0, 0), (-1, -1), 0.7, base_report.GRID),
                ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
                ("LEFTPADDING", (0, 0), (-1, -1), 10),
                ("RIGHTPADDING", (0, 0), (-1, -1), 10),
            ]
        )
    )
    _, table_height = table.wrap(800, base_report.H)
    table.drawOn(c, 80, base_report.H - 148 - table_height)

    base_report.para(
        c,
        "What AI got wrong: the first simulation used the wrong comparison, and one metric mixed incompatible units.",
        80,
        452,
        790,
        20,
        "small",
    )
    base_report.para(
        c,
        "Verification limit: 37 automated checks confirmed repeatable data connections and calculations. They did not prove future outcomes. A controlled experiment is still required.",
        80,
        476,
        790,
        28,
        "small",
    )


PAGES = [
    base_report.page_1,
    page_executive_summary,
    base_report.page_3,
    page_two_by_two_design,
    page_data_trust,
    base_report.page_5,
    base_report.page_order_example,
    page_team_metrics,
    page_cost_relationships,
    page_experience_relationships,
    page_diagnosis,
    page_ai_close_look,
    page_simulation,
    page_targeted_simulation_inputs,
    page_targeted_simulation_risk,
    page_recommendation_options,
    page_next_test,
    page_operating_monitoring,
    page_ai_usage,
]


def main():
    global CURRENT_PAGE
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    c = canvas.Canvas(str(OUTPUT), pagesize=base_report.PAGE_SIZE, pageCompression=1)
    c.setTitle("ForkDash AI-first support case study")
    c.setAuthor("Candidate case study")
    c.setSubject("Plain-language decision report using observed synthetic facts and labeled simulations")
    for index, page_fn in enumerate(PAGES, start=1):
        CURRENT_PAGE = index
        page_fn(c)
        c.showPage()
    c.save()
    print(OUTPUT)


if __name__ == "__main__":
    main()
