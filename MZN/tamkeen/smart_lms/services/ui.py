from __future__ import annotations

from html import escape
from typing import Any

import streamlit as st


def apply_theme() -> None:
    """Shared corporate/education visual system. Static CSS only."""
    st.markdown(
        """
        <style>
        :root {
            --brand-900: #0f2747;
            --brand-800: #15385f;
            --brand-700: #1d4f7a;
            --brand-600: #2563a6;
            --brand-500: #2f78c4;
            --accent-500: #2a9d8f;
            --ink-900: #172033;
            --ink-700: #40506b;
            --ink-500: #6b7890;
            --surface: #ffffff;
            --surface-soft: #f5f8fc;
            --border: #dbe4ef;
            --success: #1f7a55;
            --warning: #9a6700;
            --danger: #b42318;
            --radius: 16px;
        }

        .stApp {
            background: linear-gradient(180deg, #f7faff 0%, #ffffff 42%);
            color: var(--ink-900);
        }

        .block-container {
            max-width: 1240px;
            padding-top: 2.1rem;
            padding-bottom: 4rem;
        }

        h1, h2, h3 {
            color: var(--brand-900);
            letter-spacing: -0.02em;
        }

        p, li, label, .stMarkdown {
            line-height: 1.6;
        }

        [data-testid="stSidebar"] {
            background: #0f2747;
            border-right: 1px solid #173b65;
        }

        [data-testid="stSidebar"] * {
            color: #f7fbff;
        }

        [data-testid="stSidebar"] input {
            color: #172033 !important;
            background: #ffffff !important;
        }

        [data-testid="stSidebar"] [data-baseweb="select"] * {
            color: #172033 !important;
        }

        [data-testid="stSidebar"] .stButton button {
            width: 100%;
            border-color: rgba(255,255,255,.22);
            background: rgba(255,255,255,.08);
            color: #ffffff;
        }

        .dys-brand {
            display: flex;
            gap: .8rem;
            align-items: center;
            margin: .2rem 0 1.2rem 0;
        }

        .dys-logo {
            width: 42px;
            height: 42px;
            display: grid;
            place-items: center;
            border-radius: 12px;
            background: linear-gradient(135deg, #2f78c4, #2a9d8f);
            color: white;
            font-weight: 800;
            font-size: 1.1rem;
            box-shadow: 0 8px 24px rgba(0,0,0,.15);
        }

        .dys-brand-title {
            font-weight: 800;
            font-size: 1.02rem;
            color: #ffffff;
        }

        .dys-brand-sub {
            font-size: .75rem;
            color: rgba(255,255,255,.68);
        }

        .hero {
            padding: 2.2rem 2.3rem;
            border-radius: 24px;
            background: linear-gradient(135deg, #0f2747 0%, #1d4f7a 64%, #236f80 100%);
            color: white;
            box-shadow: 0 24px 65px rgba(15,39,71,.16);
            margin-bottom: 1.5rem;
        }

        .hero h1 { color: white; margin-bottom: .45rem; }
        .hero p { color: rgba(255,255,255,.82); max-width: 800px; margin-bottom: 0; }
        .hero-kicker {
            display: inline-flex;
            border: 1px solid rgba(255,255,255,.24);
            background: rgba(255,255,255,.08);
            border-radius: 999px;
            padding: .35rem .7rem;
            font-size: .76rem;
            font-weight: 700;
            letter-spacing: .04em;
            text-transform: uppercase;
            margin-bottom: .8rem;
        }

        .section-label {
            font-size: .76rem;
            text-transform: uppercase;
            letter-spacing: .08em;
            color: var(--brand-600);
            font-weight: 800;
            margin-bottom: .25rem;
        }

        .metric-card {
            border: 1px solid var(--border);
            border-radius: var(--radius);
            padding: 1.05rem 1.1rem;
            background: rgba(255,255,255,.94);
            min-height: 118px;
            box-shadow: 0 8px 24px rgba(15,39,71,.055);
        }

        .metric-label { color: var(--ink-500); font-size: .82rem; font-weight: 700; }
        .metric-value { color: var(--brand-900); font-size: 1.85rem; font-weight: 800; margin-top: .25rem; }
        .metric-help { color: var(--ink-500); font-size: .78rem; margin-top: .15rem; }

        .panel {
            border: 1px solid var(--border);
            border-radius: var(--radius);
            padding: 1.15rem 1.2rem;
            background: var(--surface);
            box-shadow: 0 8px 24px rgba(15,39,71,.045);
        }

        .status-pill {
            display: inline-flex;
            align-items: center;
            gap: .35rem;
            padding: .24rem .56rem;
            border-radius: 999px;
            border: 1px solid var(--border);
            background: var(--surface-soft);
            font-size: .78rem;
            font-weight: 700;
            color: var(--ink-700);
        }

        .question-shell {
            border: 1px solid var(--border);
            border-radius: 20px;
            padding: 1.4rem 1.5rem;
            background: white;
            box-shadow: 0 14px 38px rgba(15,39,71,.07);
            margin: .7rem 0;
        }

        .question-number {
            color: var(--brand-600);
            font-size: .78rem;
            font-weight: 800;
            letter-spacing: .06em;
            text-transform: uppercase;
        }

        .question-prompt {
            color: var(--ink-900);
            font-size: 1.28rem;
            line-height: 1.55;
            font-weight: 700;
            margin: .45rem 0 1rem 0;
        }

        .small-note {
            color: var(--ink-500);
            font-size: .82rem;
        }

        .trust-note {
            border-left: 4px solid #2a9d8f;
            padding: .8rem 1rem;
            background: #f1fbf8;
            border-radius: 0 12px 12px 0;
            color: #23483f;
            font-size: .88rem;
        }

        div[data-testid="stButton"] > button,
        div[data-testid="stFormSubmitButton"] > button {
            min-height: 44px;
            border-radius: 11px;
            font-weight: 700;
        }

        div[data-testid="stTextInput"] input,
        div[data-testid="stNumberInput"] input,
        div[data-testid="stTextArea"] textarea {
            border-radius: 10px;
            min-height: 44px;
        }

        /* Keep Streamlit native tabs readable even when the user's app theme is dark. */
        [data-testid="stTabs"] [role="tab"] {
            font-weight: 700 !important;
            color: var(--ink-700) !important;
            opacity: 1 !important;
        }

        [data-testid="stTabs"] [role="tab"] p,
        [data-testid="stTabs"] [role="tab"] span {
            color: inherit !important;
            opacity: 1 !important;
        }

        [data-testid="stTabs"] [role="tab"][aria-selected="true"] {
            color: var(--brand-600) !important;
        }

        [data-testid="stTabs"] [data-baseweb="tab-highlight"] {
            background-color: var(--brand-600) !important;
        }

        [data-testid="stTabs"] [data-baseweb="tab-border"] {
            background-color: var(--border) !important;
        }

        @media (max-width: 700px) {
            .block-container { padding-top: 1rem; }
            .hero { padding: 1.4rem; border-radius: 18px; }
            .question-shell { padding: 1rem; }
            .question-prompt { font-size: 1.12rem; }
        }
        </style>
        """,
        unsafe_allow_html=True,
    )


def sidebar_brand() -> None:
    st.sidebar.markdown(
        """
        <div class="dys-brand">
          <div class="dys-logo">D+</div>
          <div>
            <div class="dys-brand-title">DysCalc AI</div>
            <div class="dys-brand-sub">Adaptive learning workspace</div>
          </div>
        </div>
        """,
        unsafe_allow_html=True,
    )


def page_hero(title: str, subtitle: str, kicker: str = "Learning intelligence") -> None:
    st.markdown(
        f"""
        <div class="hero">
          <div class="hero-kicker">{escape(kicker)}</div>
          <h1>{escape(title)}</h1>
          <p>{escape(subtitle)}</p>
        </div>
        """,
        unsafe_allow_html=True,
    )


def section_heading(title: str, subtitle: str | None = None) -> None:
    st.markdown(f'<div class="section-label">{escape(title)}</div>', unsafe_allow_html=True)
    if subtitle:
        st.caption(subtitle)


def metric_card(label: str, value: Any, help_text: str = "") -> None:
    st.markdown(
        f"""
        <div class="metric-card">
          <div class="metric-label">{escape(str(label))}</div>
          <div class="metric-value">{escape(str(value))}</div>
          <div class="metric-help">{escape(str(help_text))}</div>
        </div>
        """,
        unsafe_allow_html=True,
    )


def status_label(status: str | None) -> str:
    s = (status or "unknown").replace("_", " ").strip().title()
    return s


def status_pill(status: str | None) -> None:
    st.markdown(
        f'<span class="status-pill">● {escape(status_label(status))}</span>',
        unsafe_allow_html=True,
    )


def empty_state(title: str, body: str) -> None:
    st.info(f"**{title}**\n\n{body}")


def mastery_label(value: float) -> str:
    if value >= 0.85:
        return "Strong mastery"
    if value >= 0.60:
        return "Developing"
    return "Needs support"


def percent(value: float | int | None) -> str:
    try:
        return f"{float(value) * 100:.0f}%"
    except Exception:
        return "—"
