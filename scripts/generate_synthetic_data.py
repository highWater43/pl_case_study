#!/usr/bin/env python3
"""Generate deterministic, traceable synthetic ForkDash source extracts."""

import csv
import hashlib
import json
import math
import random
from collections import defaultdict
from datetime import datetime, timedelta
from pathlib import Path


SEED = 20261106
random.seed(SEED)

PROJECT_DIR = Path(__file__).resolve().parents[1]
OUTPUT_DIR = PROJECT_DIR / "data" / "raw"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

WEEK_1 = datetime(2026, 6, 1)
TREATMENT_CITIES = {"Harbor City", "Northgate", "Riverton", "Eastfield"}
CITIES = {
    "Harbor City": {"code": "HBC", "orders": 560, "quality": 0.99, "system": "nova_ops"},
    "Northgate": {"code": "NGT", "orders": 480, "quality": 1.03, "system": "legacy_ops"},
    "Riverton": {"code": "RVT", "orders": 520, "quality": 0.97, "system": "nova_ops"},
    "Eastfield": {"code": "EFD", "orders": 450, "quality": 1.01, "system": "legacy_ops"},
    "Westbrook": {"code": "WBK", "orders": 550, "quality": 0.98, "system": "nova_ops"},
    "Lakeside": {"code": "LKS", "orders": 470, "quality": 1.02, "system": "legacy_ops"},
    "Summit": {"code": "SUM", "orders": 510, "quality": 0.96, "system": "nova_ops"},
    "Ridgemont": {"code": "RGM", "orders": 460, "quality": 1.04, "system": "legacy_ops"},
}


def bounded(value, low, high):
    return max(low, min(high, value))


def chance(probability):
    return random.random() < bounded(probability, 0.0, 1.0)


def money(value):
    return f"{value:.2f}"


def raw_money(value):
    if chance(0.06):
        return f"${value:.2f}"
    return money(value)


def raw_customer_ref(canonical):
    draw = random.random()
    if draw < 0.04:
        return ""
    if draw < 0.09:
        return canonical.lower()
    if draw < 0.13:
        return f" {canonical} "
    return canonical


def raw_order_ref(order_id):
    draw = random.random()
    if draw < 0.07:
        return ""
    if draw < 0.10:
        return order_id.lower()
    if draw < 0.12:
        return f" {order_id} "
    return order_id


def write_csv(filename, fieldnames, rows):
    path = OUTPUT_DIR / filename
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)
    return path


customers = []
customer_map = []
customer_health = {}
for city, attrs in CITIES.items():
    for index in range(1, 901):
        customer_id = f"CUS-{attrs['code']}-{index:05d}"
        crm_ref = f"CRM-{attrs['code']}-{index:05d}"
        customers.append({"customer_id": customer_id, "crm_ref": crm_ref, "city": city})
        customer_health[customer_id] = 1.0
        customer_map.append(
            {
                "crm_customer_ref": crm_ref,
                "ops_customer_id": customer_id,
                "effective_from": "2026-01-01",
                "effective_to": "",
                "match_method": "deterministic_id_map",
                "confidence_score": "1.00",
                "extract_batch_id": "MAP-2026-09-15",
            }
        )

# Add a small number of stale and ambiguous map rows. Staging ranks the active,
# high-confidence mapping and the trust mart reports the discarded records.
for source in random.sample(customer_map, 36):
    customer_map.append(
        {
            "crm_customer_ref": source["crm_customer_ref"].lower(),
            "ops_customer_id": source["ops_customer_id"],
            "effective_from": "2025-01-01",
            "effective_to": "2025-12-31",
            "match_method": "legacy_fuzzy_map",
            "confidence_score": "0.72",
            "extract_batch_id": "MAP-2026-09-15",
        }
    )

city_customers = defaultdict(list)
for customer in customers:
    city_customers[customer["city"]].append(customer)

orders = []
contacts = []
finance = []
order_issues = []
support_journey_events = []
order_context = {}
contact_sequence = 0
ledger_sequence = 0
journey_event_sequence = 0


def add_journey_event(
    contact_id,
    conversation_id,
    order_id,
    event_ts,
    event_type,
    actor_type,
    event_detail="",
    queue_name="",
    agent_id="",
):
    global journey_event_sequence
    journey_event_sequence += 1
    support_journey_events.append(
        {
            "event_id": f"EVT-{journey_event_sequence:09d}",
            "conversation_id": conversation_id,
            "contact_id": contact_id,
            "order_id": order_id,
            "event_ts": event_ts.strftime("%Y-%m-%d %H:%M:%S"),
            "event_type": event_type,
            "actor_type": actor_type,
            "queue_name": queue_name,
            "agent_id": agent_id,
            "event_detail": event_detail,
            "model_version": "forkbot-v3.2" if actor_type == "ai" else "",
            "policy_version": "contact-simplification-v1" if actor_type == "ai" else "",
            "extract_batch_id": "JOURNEY-2026-09-16",
        }
    )


def add_contact(order, contact_ts, issue_type, is_repeat=False):
    global contact_sequence
    contact_sequence += 1
    treated_post = order["treated_post"]

    if treated_post:
        channel = random.choices(["ai_chat", "phone", "email"], weights=[0.84, 0.04, 0.12])[0]
    else:
        channel = random.choices(["ai_chat", "phone", "email"], weights=[0.46, 0.36, 0.18])[0]

    if channel == "ai_chat":
        if treated_post:
            outcome = random.choices(
                ["ai_resolved", "agent_resolved", "ai_abandoned", "queue_abandoned", "unresolved"],
                weights=[0.48, 0.20, 0.14, 0.10, 0.08],
            )[0]
        else:
            outcome = random.choices(
                ["ai_resolved", "agent_resolved", "ai_abandoned", "queue_abandoned", "unresolved"],
                weights=[0.43, 0.39, 0.07, 0.04, 0.07],
            )[0]
        handling = "AI_ONLY" if outcome in {"ai_resolved", "ai_abandoned", "unresolved"} else "AI_TO_AGENT"
    else:
        outcome = random.choices(
            ["agent_resolved", "abandoned", "unresolved"], weights=[0.86, 0.07, 0.07]
        )[0]
        handling = "AGENT"

    resolved_true = outcome in {"ai_resolved", "agent_resolved"}
    # The CRM flag is intentionally optimistic for AI exits and should not be
    # treated as verified resolution without checking follow-up behavior.
    crm_resolved = resolved_true or (
        channel == "ai_chat" and outcome in {"ai_abandoned", "queue_abandoned"} and chance(0.42)
    )
    if chance(0.02):
        crm_resolved = not crm_resolved

    response_probability = 0.38 if resolved_true else 0.24
    csat = ""
    if chance(response_probability):
        mean = 4.25 if resolved_true else 2.05
        if treated_post:
            mean -= 0.30
        if is_repeat:
            mean -= 0.35
        score = int(round(bounded(random.gauss(mean, 0.85), 1, 5)))
        csat = str(score)

    ended_reason = {
        "ai_resolved": "AI_RESOLVED",
        "agent_resolved": "AGENT_RESOLVED",
        "ai_abandoned": "CUSTOMER_ABANDONED",
        "queue_abandoned": "CUSTOMER_ABANDONED",
        "abandoned": "CUSTOMER_ABANDONED",
        "unresolved": "NO_RESOLUTION",
    }[outcome]
    channel_raw = {
        "ai_chat": random.choice(["AI Chat", "chat", "AI_CHAT"]),
        "phone": random.choice(["Phone", "PHONE", "voice"]),
        "email": random.choice(["Email", "EMAIL", "mail"]),
    }[channel]

    contact = {
        "contact_id": f"CON-{contact_sequence:08d}",
        "customer_ref": raw_customer_ref(order["crm_ref"]),
        "order_ref": raw_order_ref(order["order_id"]),
        "contact_ts": contact_ts.strftime("%Y-%m-%d %H:%M:%S"),
        "channel": channel_raw,
        "issue_type": issue_type.upper() if chance(0.08) else issue_type,
        "handling": handling,
        "ended_reason": ended_reason,
        "crm_resolved_flag": "Y" if crm_resolved else "N",
        "csat_score": csat,
        "extract_batch_id": "CRM-2026-09-15",
        "source_updated_at": (contact_ts + timedelta(hours=random.randint(1, 48))).strftime("%Y-%m-%d %H:%M:%S"),
    }
    contacts.append(contact)

    contact_id = contact["contact_id"]
    conversation_id = f"CV-{contact_sequence:08d}"
    add_journey_event(
        contact_id,
        conversation_id,
        order["order_id"],
        contact_ts,
        "contact_started",
        "customer",
        event_detail=f"channel={channel}; issue={issue_type}",
    )

    if channel == "ai_chat":
        ai_start = contact_ts + timedelta(seconds=random.randint(1, 12))
        intent_ts = ai_start + timedelta(seconds=random.randint(15, 75))
        attempt_ts = intent_ts + timedelta(seconds=random.randint(35, 150))
        add_journey_event(contact_id, conversation_id, order["order_id"], ai_start, "ai_started", "ai")
        add_journey_event(
            contact_id,
            conversation_id,
            order["order_id"],
            intent_ts,
            "intent_detected",
            "ai",
            event_detail=f"intent={issue_type}",
        )
        add_journey_event(
            contact_id,
            conversation_id,
            order["order_id"],
            attempt_ts,
            "ai_resolution_attempted",
            "ai",
        )

        if outcome == "ai_resolved":
            resolved_ts = attempt_ts + timedelta(seconds=random.randint(45, 210))
            add_journey_event(contact_id, conversation_id, order["order_id"], resolved_ts, "resolved", "ai")
        elif outcome == "ai_abandoned":
            abandoned_ts = attempt_ts + timedelta(seconds=random.randint(30, 240))
            add_journey_event(
                contact_id,
                conversation_id,
                order["order_id"],
                abandoned_ts,
                "customer_abandoned",
                "customer",
                event_detail="abandoned_during_ai",
            )
        else:
            failure_delay = random.uniform(2.5, 7.5) if treated_post else random.uniform(1.5, 4.5)
            failure_ts = attempt_ts + timedelta(minutes=failure_delay)
            add_journey_event(contact_id, conversation_id, order["order_id"], failure_ts, "ai_failed", "ai")

            creates_escalation = outcome in {"agent_resolved", "queue_abandoned"}
            if creates_escalation or chance(0.45 if treated_post else 0.30):
                request_ts = failure_ts + timedelta(seconds=random.randint(15, 90))
                if chance(0.78):
                    add_journey_event(
                        contact_id,
                        conversation_id,
                        order["order_id"],
                        request_ts,
                        "human_requested",
                        "customer",
                    )
                escalation_ts = request_ts + timedelta(seconds=random.randint(10, 75))
                if creates_escalation:
                    queue_name = "priority_care" if issue_type in {"wrong_item", "cancelled"} else "general_care"
                    add_journey_event(
                        contact_id,
                        conversation_id,
                        order["order_id"],
                        escalation_ts,
                        "escalation_created",
                        "system",
                        queue_name=queue_name,
                    )
                    queue_ts = escalation_ts + timedelta(seconds=random.randint(2, 20))
                    add_journey_event(
                        contact_id,
                        conversation_id,
                        order["order_id"],
                        queue_ts,
                        "queue_entered",
                        "system",
                        queue_name=queue_name,
                    )
                    target_wait = random.lognormvariate(
                        math.log(5.5 if treated_post else 2.2), 0.48
                    )
                    if outcome == "queue_abandoned":
                        abandoned_ts = queue_ts + timedelta(minutes=max(0.5, target_wait * random.uniform(0.35, 0.90)))
                        add_journey_event(
                            contact_id,
                            conversation_id,
                            order["order_id"],
                            abandoned_ts,
                            "customer_abandoned",
                            "customer",
                            event_detail="abandoned_in_agent_queue",
                            queue_name=queue_name,
                        )
                    else:
                        agent_id = f"AGT-{random.randint(1, 180):04d}"
                        accepted_ts = queue_ts + timedelta(minutes=target_wait)
                        response_ts = accepted_ts + timedelta(seconds=random.randint(15, 95))
                        resolved_ts = response_ts + timedelta(minutes=random.uniform(4.0, 18.0))
                        add_journey_event(contact_id, conversation_id, order["order_id"], accepted_ts, "agent_accepted", "agent", queue_name=queue_name, agent_id=agent_id)
                        add_journey_event(contact_id, conversation_id, order["order_id"], response_ts, "agent_first_response", "agent", queue_name=queue_name, agent_id=agent_id)
                        add_journey_event(contact_id, conversation_id, order["order_id"], resolved_ts, "resolved", "agent", queue_name=queue_name, agent_id=agent_id)
                else:
                    add_journey_event(
                        contact_id,
                        conversation_id,
                        order["order_id"],
                        escalation_ts,
                        "escalation_failed",
                        "system",
                        event_detail="no_eligible_route",
                    )
            if outcome == "unresolved":
                end_ts = failure_ts + timedelta(minutes=random.uniform(0.5, 2.0))
                add_journey_event(contact_id, conversation_id, order["order_id"], end_ts, "contact_ended_unresolved", "system")
    else:
        queue_name = "phone_care" if channel == "phone" else "email_care"
        queue_ts = contact_ts + timedelta(seconds=random.randint(5, 35))
        add_journey_event(contact_id, conversation_id, order["order_id"], queue_ts, "queue_entered", "system", queue_name=queue_name)
        target_wait = random.lognormvariate(math.log(1.8 if channel == "phone" else 18.0), 0.50)
        if outcome == "abandoned":
            abandoned_ts = queue_ts + timedelta(minutes=max(0.4, target_wait * random.uniform(0.30, 0.85)))
            add_journey_event(contact_id, conversation_id, order["order_id"], abandoned_ts, "customer_abandoned", "customer", queue_name=queue_name)
        else:
            agent_id = f"AGT-{random.randint(1, 180):04d}"
            accepted_ts = queue_ts + timedelta(minutes=target_wait)
            response_ts = accepted_ts + timedelta(seconds=random.randint(10, 120))
            add_journey_event(contact_id, conversation_id, order["order_id"], accepted_ts, "agent_accepted", "agent", queue_name=queue_name, agent_id=agent_id)
            add_journey_event(contact_id, conversation_id, order["order_id"], response_ts, "agent_first_response", "agent", queue_name=queue_name, agent_id=agent_id)
            if outcome == "agent_resolved":
                resolved_ts = response_ts + timedelta(minutes=random.uniform(4.0, 22.0))
                add_journey_event(contact_id, conversation_id, order["order_id"], resolved_ts, "resolved", "agent", queue_name=queue_name, agent_id=agent_id)
            else:
                end_ts = response_ts + timedelta(minutes=random.uniform(2.0, 8.0))
                add_journey_event(contact_id, conversation_id, order["order_id"], end_ts, "contact_ended_unresolved", "agent", queue_name=queue_name, agent_id=agent_id)
    return {"resolved_true": resolved_true, "outcome": outcome, "channel": channel}


for week in range(1, 13):
    week_start = WEEK_1 + timedelta(days=(week - 1) * 7)
    promo_active = week >= 8
    seasonality = 1.0 + 0.018 * (week - 1)
    if promo_active:
        seasonality *= 1.13

    for city, attrs in CITIES.items():
        city_pool = city_customers[city]
        order_count = max(100, int(random.gauss(attrs["orders"] * seasonality, attrs["orders"] * 0.035)))
        weights = [customer_health[item["customer_id"]] for item in city_pool]
        selected_customers = random.choices(city_pool, weights=weights, k=order_count)

        for position, customer in enumerate(selected_customers, 1):
            order_id = f"ORD-{attrs['code']}-{week:02d}-{position:05d}"
            order_ts = week_start + timedelta(
                days=random.randint(0, 6), hours=random.randint(10, 22), minutes=random.randint(0, 59)
            )
            promo_code = "FREEDEL" if promo_active and chance(0.68) else ""
            order_value = bounded(random.lognormvariate(math.log(31), 0.42), 8.0, 125.0)
            promised_minutes = random.choice([30, 35, 40, 45, 50])
            cancellation = chance(0.027 + (0.006 if promo_active else 0.0))
            late_probability = 0.075 * attrs["quality"] + (0.022 if promo_active else 0.0)
            is_late = (not cancellation) and chance(late_probability)
            delivery_minutes = 0 if cancellation else int(random.gauss(promised_minutes - 3, 6))
            if is_late:
                delivery_minutes = promised_minutes + random.randint(8, 35)
            delivery_minutes = max(0, delivery_minutes)

            issue_type = "none"
            if cancellation:
                issue_type = "cancelled"
            elif is_late:
                issue_type = "late_order"
            elif chance(0.022 + (0.004 if promo_active else 0.0)):
                issue_type = "missing_item"
            elif chance(0.016):
                issue_type = "wrong_item"

            treated_post = city in TREATMENT_CITIES and week >= 7
            contact_probability = {
                "none": 0.013,
                "late_order": 0.58,
                "missing_item": 0.72,
                "wrong_item": 0.69,
                "cancelled": 0.46,
            }[issue_type]
            if treated_post:
                contact_probability *= 0.74

            src_system = attrs["system"]
            promised_raw = promised_minutes * 60 if src_system == "legacy_ops" else promised_minutes
            delivery_raw = delivery_minutes * 60 if src_system == "legacy_ops" else delivery_minutes
            status_code = "CXL" if cancellation and src_system == "legacy_ops" else "CANCELLED" if cancellation else "DLV" if src_system == "legacy_ops" else "DELIVERED"
            order_value_raw = raw_money(order_value)
            order_row = {
                "order_id": order_id,
                "customer_id": customer["customer_id"],
                "city": city,
                "src_system": src_system,
                "order_ts": order_ts.strftime("%Y-%m-%d %H:%M:%S"),
                "restaurant_id": f"RST-{attrs['code']}-{random.randint(1, 90):03d}",
                "order_value": order_value_raw,
                "promised_duration": str(promised_raw),
                "delivery_duration": str(delivery_raw),
                "status_code": status_code,
                "promo_code": promo_code,
                "extract_batch_id": "OPS-2026-09-01",
            }
            orders.append(order_row)

            if issue_type != "none":
                severity = {
                    "late_order": "medium",
                    "missing_item": "medium",
                    "wrong_item": "high",
                    "cancelled": "high",
                }[issue_type]
                detected_minutes = max(2, delivery_minutes + 5)
                order_issues.append(
                    {
                        "issue_id": f"ISS-{order_id}",
                        "order_id": order_id,
                        "customer_id": customer["customer_id"],
                        "issue_detected_ts": (order_ts + timedelta(minutes=detected_minutes)).strftime("%Y-%m-%d %H:%M:%S"),
                        "issue_type": issue_type,
                        "issue_severity": severity,
                        "detection_source": "operations" if issue_type in {"late_order", "cancelled"} else "synthetic_order_truth",
                        "contact_eligible_flag": "true",
                        "extract_batch_id": "ISSUE-2026-09-15",
                    }
                )

            context = {
                "order_id": order_id,
                "customer_id": customer["customer_id"],
                "crm_ref": customer["crm_ref"],
                "city": city,
                "week": week,
                "order_ts": order_ts,
                "order_value": order_value,
                "issue_type": issue_type,
                "treated_post": treated_post,
                "contacted": False,
                "resolved_true": issue_type == "none",
                "repeat_contact": False,
            }

            if chance(contact_probability):
                context["contacted"] = True
                contact_ts = order_ts + timedelta(hours=random.randint(1, 30))
                first = add_contact(context, contact_ts, issue_type)
                context["resolved_true"] = first["resolved_true"]
                repeat_probability = 0.07 if first["resolved_true"] else 0.43
                if treated_post:
                    repeat_probability += 0.09
                if chance(repeat_probability):
                    context["repeat_contact"] = True
                    repeat_ts = contact_ts + timedelta(days=random.randint(1, 6), hours=random.randint(0, 12))
                    second = add_contact(context, repeat_ts, issue_type, is_repeat=True)
                    context["resolved_true"] = context["resolved_true"] or second["resolved_true"]

            order_context[order_id] = context

            # Financial recovery. Friction suppresses immediate credits but raises
            # delayed chargebacks for unresolved problems.
            if issue_type != "none":
                refund_probability = 0.25 if issue_type == "late_order" else 0.58
                if treated_post:
                    refund_probability *= 0.83
                if context["contacted"] and context["resolved_true"] and chance(refund_probability):
                    ledger_sequence += 1
                    refund_amount = order_value * random.uniform(0.28, 1.0)
                    finance.append(
                        {
                            "ledger_id": f"LED-{ledger_sequence:08d}",
                            "order_id": order_id,
                            "posted_date": (order_ts + timedelta(days=random.randint(1, 6))).strftime("%Y-%m-%d"),
                            "amount_usd": raw_money(-refund_amount),
                            "entry_type": random.choice(["REFUND", "CUSTOMER_CREDIT"]),
                            "reason_code": issue_type.upper(),
                            "extract_batch_id": "FIN-2026-09-20",
                        }
                    )

                base_chargeback = 0.008
                if not context["resolved_true"]:
                    base_chargeback = 0.075
                if not context["contacted"]:
                    base_chargeback += 0.022
                if treated_post:
                    base_chargeback *= 1.62
                if chance(base_chargeback):
                    posted_date = order_ts + timedelta(days=random.randint(8, 30))
                    ledger_sequence += 1
                    finance.append(
                        {
                            "ledger_id": f"LED-{ledger_sequence:08d}",
                            "order_id": order_id,
                            "posted_date": posted_date.strftime("%Y-%m-%d"),
                            "amount_usd": raw_money(-order_value),
                            "entry_type": "CHARGEBACK",
                            "reason_code": "SERVICE_NOT_RECEIVED" if issue_type in {"cancelled", "late_order"} else "PRODUCT_NOT_AS_DESCRIBED",
                            "extract_batch_id": "FIN-2026-09-20",
                        }
                    )
                    ledger_sequence += 1
                    finance.append(
                        {
                            "ledger_id": f"LED-{ledger_sequence:08d}",
                            "order_id": order_id,
                            "posted_date": posted_date.strftime("%Y-%m-%d"),
                            "amount_usd": raw_money(-18.0),
                            "entry_type": "CHARGEBACK_FEE",
                            "reason_code": "PROCESSOR_FEE",
                            "extract_batch_id": "FIN-2026-09-20",
                        }
                    )

            if issue_type != "none" and (not context["resolved_true"] or context["repeat_contact"]):
                customer_health[customer["customer_id"]] *= 0.45 if treated_post else 0.89
                customer_health[customer["customer_id"]] = max(0.15, customer_health[customer["customer_id"]])

# Append exact duplicate CRM extract rows and late-arriving corrected versions.
for duplicate in random.sample(contacts, max(1, len(contacts) // 100)):
    contacts.append(dict(duplicate))
for corrected in random.sample(contacts[: max(1, len(contacts) // 2)], max(1, len(contacts) // 150)):
    revised = dict(corrected)
    revised["source_updated_at"] = "2026-09-16 12:00:00"
    if revised["ended_reason"] == "NO_RESOLUTION":
        revised["crm_resolved_flag"] = "N"
    contacts.append(revised)

experiment_assignment = []
for city, attrs in CITIES.items():
    experiment_assignment.append(
        {
            "city": city,
            "city_code": attrs["code"],
            "treatment_group": "treatment" if city in TREATMENT_CITIES else "control",
            "launch_week": "7" if city in TREATMENT_CITIES else "",
            "launch_date": "2026-07-13" if city in TREATMENT_CITIES else "",
            "policy_description": "AI-first; phone removed" if city in TREATMENT_CITIES else "unchanged contact access",
        }
    )

# A modeled loyalty scenario is kept separate from observed order behavior.
loyalty_scenario = []
contexts_by_customer = defaultdict(list)
for item in order_context.values():
    contexts_by_customer[item["customer_id"]].append(item)
for customer in customers:
    contexts = contexts_by_customer[customer["customer_id"]]
    bad_experiences = sum(1 for item in contexts if item["issue_type"] != "none" and not item["resolved_true"])
    repeat_contacts = sum(1 for item in contexts if item["repeat_contact"])
    risk_score = bounded(0.08 + 0.16 * bad_experiences + 0.09 * repeat_contacts, 0.02, 0.85)
    loyalty_scenario.append(
        {
            "customer_id": customer["customer_id"],
            "scenario_as_of_date": "2026-09-01",
            "scenario_version": "v1_assumption_only",
            "modeled_90d_churn_probability": f"{risk_score:.4f}",
            "modeled_90d_order_reduction": f"{bounded(risk_score * 0.55, 0.0, 0.50):.4f}",
            "simulated_flag": "true",
        }
    )

files = []
files.append(write_csv("orders_ops.csv", list(orders[0]), orders))
files.append(write_csv("support_contacts.csv", list(contacts[0]), contacts))
files.append(write_csv("finance_ledger.csv", list(finance[0]), finance))
files.append(write_csv("customer_map.csv", list(customer_map[0]), customer_map))
files.append(write_csv("experiment_assignment.csv", list(experiment_assignment[0]), experiment_assignment))
files.append(write_csv("loyalty_scenario.csv", list(loyalty_scenario[0]), loyalty_scenario))
files.append(write_csv("order_issues.csv", list(order_issues[0]), order_issues))
files.append(write_csv("support_journey_events.csv", list(support_journey_events[0]), support_journey_events))

manifest = {
    "seed": SEED,
    "generated_at": "2026-11-06T13:00:00-05:00",
    "scenario": "ForkDash Contact Us Simplification",
    "counts": {
        "orders_ops": len(orders),
        "support_contacts_raw_rows": len(contacts),
        "finance_ledger": len(finance),
        "customer_map_raw_rows": len(customer_map),
        "experiment_assignment": len(experiment_assignment),
        "loyalty_scenario": len(loyalty_scenario),
        "order_issues": len(order_issues),
        "support_journey_events": len(support_journey_events),
    },
    "files": {},
}
for path in files:
    manifest["files"][path.name] = hashlib.sha256(path.read_bytes()).hexdigest()

with (OUTPUT_DIR / "manifest.json").open("w", encoding="utf-8") as handle:
    json.dump(manifest, handle, indent=2, sort_keys=True)
    handle.write("\n")

print(json.dumps(manifest["counts"], indent=2, sort_keys=True))
