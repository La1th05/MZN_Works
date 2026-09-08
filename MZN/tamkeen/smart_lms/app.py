from __future__ import annotations

import streamlit as st

from services.auth import authenticate_user, logout
from services.db import init_db
from services.ui import apply_theme, page_hero, sidebar_brand

st.set_page_config(
    page_title="DysCalc AI",
    page_icon="🎓",
    layout="wide",
    initial_sidebar_state="expanded",
)

init_db()
apply_theme()
sidebar_brand()

user = st.session_state.get("user")

if user:
    st.sidebar.caption("Signed in")
    st.sidebar.write(f"**{user.get('display_name') or user.get('email')}**")
    st.sidebar.caption(f"{user.get('email')} · {str(user.get('role', '')).title()}")
    if st.sidebar.button("Sign out", use_container_width=True):
        logout()

page_hero(
    "Adaptive math support, designed for learning clarity.",
    "A focused learning workspace for teachers and students using assessment data, mastery tracking, and adaptive support without adding unnecessary cognitive load.",
    "DysCalc AI · Education intelligence",
)

if not user:
    left, right = st.columns([1.15, 0.85], gap="large")
    with left:
        st.subheader("Built for learning, not dashboard clutter")
        st.markdown(
            """
            - **Student-first assessment flow** with one question in focus at a time.
            - **Teacher visibility** into classes, assignments, mastery, and learning support signals.
            - **Adaptive recommendations** that translate model output into understandable next steps.
            - **Accessible structure** with high contrast, larger controls, consistent spacing, and calm status cues.
            """
        )
        st.markdown(
            '<div class="trust-note"><strong>Privacy-first UX principle:</strong> behavioral signals should be treated as support indicators, not diagnoses or labels about a learner.</div>',
            unsafe_allow_html=True,
        )

    with right:
        st.subheader("Sign in")
        with st.form("main_login_form", clear_on_submit=False):
            email = st.text_input("Email", placeholder="you@school.edu")
            password = st.text_input("Password", type="password", placeholder="Enter your password")
            submitted = st.form_submit_button("Continue", type="primary", use_container_width=True)
        if submitted:
            u = authenticate_user(email, password)
            if not u:
                st.error("The email or password is incorrect, or the account is inactive.")
            else:
                st.session_state["user"] = u
                st.rerun()

else:
    role = user.get("role")
    st.subheader(f"Welcome, {user.get('display_name') or 'learner'}")
    st.write("Choose your workspace to continue.")
    c1, c2 = st.columns(2)
    if role == "teacher":
        with c1:
            if st.button("Open Teacher Workspace", type="primary", use_container_width=True):
                st.switch_page("pages/1_Teacher.py")
        with c2:
            st.info("Manage classes, build assessments, and review learner progress.")
    elif role == "student":
        with c1:
            if st.button("Open Student Workspace", type="primary", use_container_width=True):
                st.switch_page("pages/2_Student.py")
        with c2:
            st.info("Continue assessments, practice skills, and review your progress.")
    else:
        st.error("This account has an unsupported role. Ask an administrator to review it.")
