"""
SmartStickies Badge Collector - Flask frontend
------------------------------------------------
This app is the "customer-facing" client described in the task brief.
It owns zero badge-earning logic -- every decision about who earns what
lives in the Badge Collector backend. This app just:

  1. Collects login/signup forms and stores the returned Bearer token
     in the Flask session.
  2. Calls the backend API and renders whatever it gets back.
  3. Shows a celebration screen when a purchase action unlocks a badge.

See README.md for setup instructions and for a few backend quirks this
frontend has to work around.
"""

import os

from dotenv import load_dotenv
from flask import Flask, flash, redirect, render_template, request, session, url_for
from functools import wraps

import badge_api

load_dotenv()

app = Flask(__name__)
app.secret_key = os.environ.get("FLASK_SECRET_KEY", "dev-secret-change-me")

# Demo catalog for the Purchase Demo page. Names/prices match the backend's
# priv/repo/seeds.exs so a fresh demo lines up with the badges that are
# actually seeded (First Purchase, Bought Ten Items, Spent Fifty, ...).
DEMO_ITEMS = [
    {"name": "Blue Sticker", "cost": "4.50", "emoji": "🔵"},
    {"name": "Gold Star", "cost": "12.00", "emoji": "⭐"},
    {"name": "Holographic Cat", "cost": "21.25", "emoji": "🐱"},
    {"name": "Enamel Pin", "cost": "15.00", "emoji": "📌"},
    {"name": "Mystery Box", "cost": "9.99", "emoji": "🎁"},
]

UNLOCK_TYPE_LABELS = {
    "login_streak": "Log in {args} day(s) in a row",
    "purchase_count": "Make {args} purchase(s)",
    "total_spent": "Spend ${args} in total",
}


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def login_required(view):
    @wraps(view)
    def wrapped(*args, **kwargs):
        if not session.get("token"):
            flash("Please log in first.", "error")
            return redirect(url_for("login"))
        return view(*args, **kwargs)
    return wrapped


def describe_unlock(badge: dict) -> str:
    """Turn unlock_type/unlock_args into a readable sentence for a badge card."""
    unlock_type = badge.get("unlock_type")
    args = badge.get("unlock_args")
    template = UNLOCK_TYPE_LABELS.get(unlock_type)
    if template and args is not None:
        try:
            return template.format(args=args)
        except (ValueError, KeyError):
            pass
    return "Special criteria"


def fetch_full_badges(token):
    """Calls GET /api/badges and returns (acquired_list, missing_list, api_result).

    acquired/missing come back as None (instead of raising) if the request
    failed OR if the backend responded with something that isn't a list --
    which is currently the case due to a backend bug, see README.md.
    """
    result = badge_api.get_badges(token)
    if not result.ok:
        return None, None, result

    data = result.data if isinstance(result.data, dict) else {}
    acquired = data.get("acquired")
    missing = data.get("missing")
    if isinstance(acquired, list) and isinstance(missing, list):
        return acquired, missing, result
    return None, None, result


# ---------------------------------------------------------------------------
# Routes: auth
# ---------------------------------------------------------------------------

@app.route("/")
def index():
    return redirect(url_for("badges") if session.get("token") else url_for("login"))


@app.route("/signup", methods=["GET", "POST"])
def signup():
    if request.method == "GET":
        return render_template("signup.html")

    email = request.form.get("email", "").strip()
    password = request.form.get("password", "")

    if not email or not password:
        flash("Email and password are both required.", "error")
        return render_template("signup.html", email=email)

    result = badge_api.signup(email, password)
    if not result.ok:
        flash(result.error_message(), "error")
        return render_template("signup.html", email=email)

    token = (result.data or {}).get("token")
    if not token:
        flash("Signup succeeded but no token was returned by the API.", "error")
        return render_template("signup.html", email=email)

    session["token"] = token
    session["email"] = email
    badge_api.record_login(token)  # start the login streak on day one
    flash(f"Welcome to SmartStickies, {email}!", "success")
    return redirect(url_for("badges"))


@app.route("/login", methods=["GET", "POST"])
def login():
    if request.method == "GET":
        return render_template("login.html")

    email = request.form.get("email", "").strip()
    password = request.form.get("password", "")

    if not email or not password:
        flash("Email and password are both required.", "error")
        return render_template("login.html", email=email)

    result = badge_api.login(email, password)
    if not result.ok:
        flash(result.error_message(), "error")
        return render_template("login.html", email=email)

    token = (result.data or {}).get("token")
    if not token:
        flash("Login succeeded but no token was returned by the API.", "error")
        return render_template("login.html", email=email)

    session["token"] = token
    session["email"] = email
    badge_api.record_login(token)  # log today's visit for login-streak badges
    flash(f"Welcome back, {email}!", "success")
    return redirect(url_for("badges"))


@app.route("/logout")
def logout():
    session.clear()
    flash("You've been logged out.", "success")
    return redirect(url_for("login"))


# ---------------------------------------------------------------------------
# Routes: badge collection
# ---------------------------------------------------------------------------

@app.route("/badges")
@login_required
def badges():
    token = session["token"]
    acquired, missing, result = fetch_full_badges(token)

    if not result.ok:
        flash(result.error_message(), "error")

    api_broken = result.ok and acquired is None

    for badge in (acquired or []):
        badge["description"] = describe_unlock(badge)
    for badge in (missing or []):
        badge["description"] = describe_unlock(badge)

    return render_template(
        "badges.html",
        earned=acquired or [],
        locked=missing or [],
        api_broken=api_broken,
    )


# ---------------------------------------------------------------------------
# Routes: purchase demo
# ---------------------------------------------------------------------------

@app.route("/purchase")
@login_required
def purchase():
    return render_template("purchase.html", items=DEMO_ITEMS)


@app.route("/purchase/buy", methods=["POST"])
@login_required
def buy_item():
    token = session["token"]
    item_name = request.form.get("item_name", "").strip()
    cost = request.form.get("cost", "").strip()

    if not item_name or not cost:
        flash("Missing item name or cost.", "error")
        return redirect(url_for("purchase"))

    # Snapshot what's earned *before* the purchase so we can tell exactly
    # which badge(s) are new, since the "certificates" the action endpoint
    # returns don't include badge names (see README.md).
    before_acquired, _, _ = fetch_full_badges(token)
    before_names = {b.get("name") for b in before_acquired} if before_acquired is not None else None

    action_result = badge_api.record_purchase(token, item_name, cost)
    if not action_result.ok:
        flash(f"Purchase failed: {action_result.error_message()}", "error")
        return redirect(url_for("purchase"))

    certificates = (action_result.data or {}).get("certificates") or []

    after_acquired, _, _ = fetch_full_badges(token)
    after_names = {b.get("name") for b in after_acquired} if after_acquired is not None else None

    unlocked = []
    if before_names is not None and after_names is not None:
        new_names = after_names - before_names
        unlocked = [b for b in after_acquired if b.get("name") in new_names]
        for badge in unlocked:
            badge["description"] = describe_unlock(badge)

    if not unlocked and certificates:
        # /api/badges isn't giving us usable data right now (backend bug),
        # so fall back to the minimal info the actions endpoint did give us.
        unlocked = [
            {
                "name": f"Badge #{c.get('badge_id')}",
                "cert_info": c.get("info"),
                "certified_at": c.get("at"),
                "fallback": True,
            }
            for c in certificates
        ]

    if unlocked:
        return render_template("badge_unlocked.html", unlocked=unlocked, item_name=item_name, cost=cost)

    flash(f"Bought {item_name} for ${cost}. No new badge unlocked this time — keep tapping!", "success")
    return redirect(url_for("purchase"))


if __name__ == "__main__":
    app.run(debug=True, port=5000)
