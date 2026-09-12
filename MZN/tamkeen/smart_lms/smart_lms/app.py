from __future__ import annotations

import streamlit as st

from services.auth import authenticate_user, logout
from services.db import init_db
from services.ui import apply_theme, page_hero, sidebar_brand

# NEW: language system
from services.i18n import (
    t,
    language_switcher,
    apply_language_direction,
)


# ============================================================
# PAGE CONFIG
# ============================================================

st.set_page_config(
    page_title="DysCalc AI",
    page_icon="🎓",
    layout="wide",
    initial_sidebar_state="expanded",
)


# ============================================================
# INITIALIZATION
# ============================================================

init_db()

apply_theme()

# Language selector
language_switcher()

# Arabic RTL / English LTR
apply_language_direction()

sidebar_brand()


# ============================================================
# CURRENT USER
# ============================================================

user = st.session_state.get("user")


# ============================================================
# SIDEBAR USER INFO
# ============================================================

if user:

    st.sidebar.caption(
        t("app.signed_in")
    )

    st.sidebar.write(
        f"**{user.get('display_name') or user.get('email')}**"
    )

    role = str(
        user.get("role", "")
    ).lower()

    if role == "teacher":
        role_label = t("nav.teacher")

    elif role == "student":
        role_label = t("nav.student")

    else:
        role_label = role.title()

    st.sidebar.caption(
        f"{user.get('email')} · {role_label}"
    )

    if st.sidebar.button(
        t("common.sign_out"),
        use_container_width=True,
    ):
        logout()


# ============================================================
# HERO
# ============================================================

page_hero(
    t("app.hero_title"),
    t("app.hero_text"),
    t("app.hero_kicker"),
)


# ============================================================
# NOT LOGGED IN
# ============================================================

if not user:

    left, right = st.columns(
        [1.15, 0.85],
        gap="large",
    )

    # --------------------------------------------------------
    # LEFT SIDE
    # --------------------------------------------------------

    with left:

        st.subheader(
            t("app.built_for_learning")
        )

        st.markdown(
            f"""
- {t("app.feature_student")}
- {t("app.feature_teacher")}
- {t("app.feature_adaptive")}
- {t("app.feature_accessible")}
"""
        )

        privacy_html = f"""
        <div class="trust-note">
            <strong>{t("app.privacy_title")}</strong>
            {t("app.privacy_text")}
        </div>
        """

        st.markdown(
            privacy_html,
            unsafe_allow_html=True,
        )

    # --------------------------------------------------------
    # RIGHT SIDE - LOGIN
    # --------------------------------------------------------

    with right:

        st.subheader(
            t("app.sign_in")
        )

        with st.form(
            "main_login_form",
            clear_on_submit=False,
        ):

            email = st.text_input(
                t("common.email"),
                placeholder=t(
                    "app.email_placeholder"
                ),
            )

            password = st.text_input(
                t("common.password"),
                type="password",
                placeholder=t(
                    "app.password_placeholder"
                ),
            )

            submitted = st.form_submit_button(
                t("common.continue"),
                type="primary",
                use_container_width=True,
            )

        # ----------------------------------------------------
        # LOGIN SUBMISSION
        # ----------------------------------------------------

        if submitted:

            u = authenticate_user(
                email,
                password,
            )

            if not u:

                st.error(
                    t("app.invalid_login")
                )

            else:

                st.session_state["user"] = u

                st.rerun()


# ============================================================
# LOGGED IN
# ============================================================

else:

    role = str(
        user.get("role", "")
    ).lower()

    display_name = (
        user.get("display_name")
        or user.get("email")
        or "User"
    )

    st.subheader(
        t(
            "app.welcome",
            name=display_name,
        )
    )

    st.write(
        t("app.choose_workspace")
    )

    c1, c2 = st.columns(2)


    # ========================================================
    # TEACHER
    # ========================================================

    if role == "teacher":

        with c1:

            if st.button(
                t("app.open_teacher"),
                type="primary",
                use_container_width=True,
            ):

                st.switch_page(
                    "pages/1_Teacher.py"
                )

        with c2:

            st.info(
                t("app.teacher_info")
            )


    # ========================================================
    # STUDENT
    # ========================================================

    elif role == "student":

        with c1:

            if st.button(
                t("app.open_student"),
                type="primary",
                use_container_width=True,
            ):

                st.switch_page(
                    "pages/2_Student.py"
                )

        with c2:

            st.info(
                t("app.student_info")
            )


    # ========================================================
    # UNKNOWN ROLE
    # ========================================================

    else:

        st.error(
            t("app.unsupported_role")
        )