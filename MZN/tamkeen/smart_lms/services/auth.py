import hashlib
import hmac
import secrets
import streamlit as st

from services.db import get_conn


def _sha256(s: str) -> str:
    return hashlib.sha256((s or "").encode("utf-8")).hexdigest()


def hash_password(password: str, iterations: int = 260_000) -> str:
    """PBKDF2-SHA256 password hash stored as: pbkdf2_sha256$iters$salt_hex$hash_hex."""
    salt_hex = secrets.token_hex(16)
    dk = hashlib.pbkdf2_hmac(
        "sha256",
        (password or "").encode("utf-8"),
        bytes.fromhex(salt_hex),
        int(iterations),
    )
    return f"pbkdf2_sha256${int(iterations)}${salt_hex}${dk.hex()}"


def verify_password(password: str, stored_hash: str) -> bool:
    stored = (stored_hash or "").strip()
    if not stored:
        return False

    if stored.startswith("pbkdf2_sha256$"):
        try:
            _algo, iters, salt_hex, hash_hex = stored.split("$", 3)
            dk = hashlib.pbkdf2_hmac(
                "sha256",
                (password or "").encode("utf-8"),
                bytes.fromhex(salt_hex),
                int(iters),
            )
            return hmac.compare_digest(dk.hex(), hash_hex)
        except Exception:
            return False

    # Legacy SHA256 hex
    if len(stored) == 64 and all(c in "0123456789abcdef" for c in stored.lower()):
        return hmac.compare_digest(_sha256(password), stored.lower())

    return False


def authenticate_user(email: str, password: str):
    email = (email or "").strip().lower()
    password = password or ""
    if not email or not password:
        return None

    conn = get_conn()
    try:
        row = conn.execute(
            "SELECT id, email, role, display_name, password_hash, password, is_active "
            "FROM users WHERE lower(email)=? LIMIT 1;",
            (email,),
        ).fetchone()
        if not row:
            return None
        if int(row["is_active"] or 0) != 1:
            return None

        ok = False
        if row["password_hash"]:
            ok = verify_password(password, row["password_hash"] or "")
        else:
            ok = (row["password"] or "") == password

        if not ok:
            return None

        # Auto-upgrade legacy SHA256 to PBKDF2 on successful login
        ph = (row["password_hash"] or "").strip()
        if ph and len(ph) == 64 and all(c in "0123456789abcdef" for c in ph.lower()):
            try:
                conn.execute("UPDATE users SET password_hash=?, password=NULL WHERE id=?;", (hash_password(password), int(row["id"])))
                conn.commit()
            except Exception:
                pass

        return {
            "id": row["id"],
            "email": row["email"],
            "role": row["role"],
            "display_name": row["display_name"] or row["email"],
        }
    finally:
        conn.close()


def logout():
    for k in ["user"]:
        if k in st.session_state:
            del st.session_state[k]
    st.rerun()


def ui_login_box():
    with st.sidebar:
        st.markdown("### Login")
        user = st.session_state.get("user")
        if user:
            st.write(f"**{user.get('display_name','')}**")
            st.caption(f"{user.get('email','')} · role={user.get('role','')}")
            st.button("Logout", key="auth_logout_btn", on_click=logout)
            return

        email = st.text_input("Email", key="auth_email_in")
        pw = st.text_input("Password", type="password", key="auth_pw_in")
        if st.button("Login", key="auth_login_btn"):
            u = authenticate_user(email, pw)
            if u:
                st.session_state["user"] = u
                st.rerun()
            else:
                st.error("Invalid credentials or inactive account.")


def require_login(role=None):
    user = st.session_state.get("user")
    if not user:
        st.error("Please login from the sidebar.")
        st.stop()
    if role and user.get("role") != role:
        st.error(f"Access denied. Required role: {role}")
        st.stop()
    return user


def sha256_hex(password: str) -> str:
    """Backward compatible helper used by older UI code.

    Prefer `hash_password` for new passwords.
    """
    return _sha256(password or "")
