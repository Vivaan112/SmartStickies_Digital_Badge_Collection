# SmartStickies Badge Collector — Flask Frontend

This is the customer-facing Flask app described in the internship task:
**Customer → Flask Website → Badge Collector API → Backend returns badges.**

It talks to the real backend built by your teammate
([`SmartStickies_Digital_Badge_Collection`](https://github.com/Vivaan112/SmartStickies_Digital_Badge_Collection),
the `badge_collector` Phoenix app) over HTTP. This app doesn't decide who
earns what — it just calls the API and renders what comes back.

## 1. Setup

```bash
cd smartstickies-frontend
python3 -m venv venv
source venv/bin/activate        # Windows: venv\Scripts\activate
pip install -r requirements.txt
cp .env.example .env            # adjust BADGE_API_BASE_URL if needed
```

## 2. Run the backend first

In a separate terminal, from the `badge_collector` Phoenix project:

```bash
mix deps.get
mix ecto.setup      # or: mix ecto.create && mix ecto.migrate && mix run priv/repo/seeds.exs
mix phx.server
```

That serves the API at `http://localhost:4000` by default (see
`config/dev.exs`). The seed data creates a demo user
`jane@example.com` / `correcthorsebatterystaple` with some purchase and
login history already on her account, which is handy for testing the
"Badge Collection" page without doing a purchase first.

## 3. Run this app

```bash
python app.py
```

Visit `http://localhost:5000`. Sign up, log in, browse your badge
collection, buy something on the Purchase Demo page, and (assuming the
backend bug below is fixed) watch the unlock screen fire.

## How it's wired up (Flask/Jinja concepts used)

- **Routing** — every page in `templates/` has a matching `@app.route(...)`
  in `app.py` (e.g. `/badges`, `/purchase`).
- **Jinja templates** — `templates/base.html` is the shared layout;
  every other template `{% extends "base.html" %}` and fills in
  `{% block content %}`. Loops (`{% for badge in earned %}`) render the
  badge grids.
- **Passing data Flask → HTML** — routes call `render_template(name, **data)`;
  the keyword args become variables inside the template (see `badges.html`
  reading `earned`, `locked`, `api_broken`).
- **Forms** — `login.html`, `signup.html`, and `purchase.html` are plain
  HTML `<form method="post">`s; Flask reads them with
  `request.form.get(...)`.
- **Sessions** — `session["token"]` stores the Bearer token Flask gets
  back from `/api/login` or `/api/signup`. `login_required` in `app.py`
  is a small decorator that checks `session.get("token")` before letting
  a route run.
- **Calling external APIs** — all HTTP calls to the backend live in
  `badge_api.py`, kept separate from the routes so `app.py` stays focused
  on the user experience. It uses the `requests` library and always
  returns an `APIResult` instead of raising, so a route never crashes
  just because the backend is down or returned something unexpected.

## Known backend issues (worth flagging to your teammate)

While tracing through `badge_collector`'s source to get the exact
request/response shapes right, I found three real bugs. This frontend
works around all three defensively (so it won't crash), but the actual
fixes belong in the backend repo.

1. **`GET /api/badges` never returns real badge data.**
   `lib/badge_collector_web/controllers/badge_controller.ex` builds the
   response with `Enum.each`, which always returns `:ok` — not the list
   `Badge.to_display_information/1` produces per badge. In practice the
   endpoint currently returns `{"acquired": "ok", "missing": "ok"}`
   instead of two lists of badges. The fix is a one-word swap:
   ```elixir
   # before
   "acquired" => user |> User.earned_badges |> Enum.each(&Badge.to_display_information/1),
   "missing"  => user |> User.unearned_badges |> Enum.each(&Badge.to_display_information/1)
   # after
   "acquired" => user |> User.earned_badges |> Enum.map(&Badge.to_display_information/1),
   "missing"  => user |> User.unearned_badges |> Enum.map(&Badge.to_display_information/1)
   ```
   Until this is fixed, this app's `/badges` page will show an empty
   collection with a warning banner instead of crashing.

2. **Login streaks can never actually accumulate.**
   `SessionController.login/2` just checks the password and hands back a
   token — it never records an `Action`. But
   `LoginStreakCertifier` only looks at rows in the `actions` table with
   `type == "login"`. So unless a client explicitly calls
   `POST /api/actions` with `{"action": "login", "data": ""}` after
   authenticating, the "Showed Up" / "Three Day Habit" / "One Week
   Streak" badges can never unlock. This wasn't in the original task
   spec, but it's required for those badges to work at all, so `app.py`
   calls `badge_api.record_login()` right after a successful login or
   signup.

3. **Purchase certificates don't carry a badge name.**
   `POST /api/actions` returns `certificates: [{badge_id, info, at}]` —
   no name. And `Badge.to_display_information/1` (used by `/api/badges`)
   doesn't include the badge's `id` either, so there's no field the
   client can join on to look up "badge_id 3 = 'First Purchase'".
   This app works around it by snapshotting the earned-badge names
   *before* the purchase, re-fetching after, and diffing the two lists
   to figure out what's new (see `buy_item()` in `app.py`). If
   `/api/badges` is unavailable (e.g. bug #1 above isn't fixed yet), it
   falls back to showing `Badge #<id>` with the `info` string instead.
   A cleaner long-term fix would be adding `id: badge.id` to
   `Badge.to_display_information/1`.

4. **Minor:** `SessionController.login/2` calls
   `put_status(:unathorized)` (typo) instead of `:unauthorized` on a
   failed login. Depending on the Plug/Cowboy version this can raise
   instead of cleanly returning a 401 — worth a quick fix too.

## Project structure

```
app.py                 Flask routes / the actual "frontend" logic
badge_api.py            Thin client for the Badge Collector API (all requests calls live here)
templates/
  base.html              Shared layout, nav, flash messages
  login.html
  signup.html
  badges.html            Earned + locked badge grids
  purchase.html          Buy-demo catalog
  badge_unlocked.html     Celebration screen
static/css/style.css
.env.example
requirements.txt
```

## Environment variables

| Variable | Default | Purpose |
|---|---|---|
| `BADGE_API_BASE_URL` | `http://localhost:4000` | Where the Phoenix backend is running |
| `FLASK_SECRET_KEY` | `dev-secret-change-me` | Signs the Flask session cookie |
