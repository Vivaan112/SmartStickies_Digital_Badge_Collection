"""
badge_api.py
------------
A small, dependency-light client for the Badge Collector backend
(the Phoenix/Elixir API built by the other intern on the team).

Every function here does ONE HTTP call and always returns an APIResult
instead of raising, so routes in app.py can just check `result.ok`
and never have to worry about connection errors, timeouts, or the
backend returning something unexpected (which, as it turns out, it
sometimes does -- see README.md "Known backend issues").
"""

import os
from dataclasses import dataclass
from typing import Any, Optional

import requests

# Base URL of the badge_collector Phoenix app.
# In dev, `mix phx.server` serves it at http://localhost:4000 by default.
BASE_URL = os.environ.get("BADGE_API_BASE_URL", "http://localhost:4000").rstrip("/")

REQUEST_TIMEOUT = 5  # seconds


@dataclass
class APIResult:
    ok: bool                 # True only for a 2xx HTTP response
    status: Optional[int]    # HTTP status code, or None if we couldn't connect
    data: Any                # parsed JSON body (dict/list), or None
    raw_text: Optional[str]  # raw response body, used when JSON parsing fails
    connection_error: Optional[str] = None  # set when requests itself raised

    def error_message(self) -> str:
        """Best-effort human-readable error message, for flashing to the user."""
        if self.connection_error:
            return (
                f"Couldn't reach the Badge Collector API at {BASE_URL}. "
                f"Is the backend running? ({self.connection_error})"
            )

        if isinstance(self.data, dict):
            # The backend uses both "error" (string) and "errors" (varies) keys
            # depending on which controller answered.
            if "error" in self.data:
                return str(self.data["error"])
            if "errors" in self.data:
                errors = self.data["errors"]
                if isinstance(errors, (list, tuple)):
                    return "; ".join(str(e) for e in errors)
                return str(errors)

        if self.raw_text:
            return f"Unexpected response from the API (status {self.status}): {self.raw_text[:200]}"

        return f"Request failed (status {self.status})"


def _request(method: str, path: str, token: Optional[str] = None, json_body: Optional[dict] = None) -> APIResult:
    url = f"{BASE_URL}{path}"
    headers = {}
    if token:
        headers["Authorization"] = f"Bearer {token}"

    try:
        resp = requests.request(method, url, json=json_body, headers=headers, timeout=REQUEST_TIMEOUT)
    except requests.exceptions.RequestException as exc:
        return APIResult(ok=False, status=None, data=None, raw_text=None, connection_error=str(exc))

    data = None
    raw_text = None
    try:
        data = resp.json()
    except ValueError:
        raw_text = resp.text

    return APIResult(ok=resp.ok, status=resp.status_code, data=data, raw_text=raw_text)


# ---------------------------------------------------------------------------
# Auth
# ---------------------------------------------------------------------------

def login(email: str, password: str) -> APIResult:
    """POST /api/login -> {"token": "..."}"""
    return _request("POST", "/api/login", json_body={"email": email, "password": password})


def signup(email: str, password: str) -> APIResult:
    """POST /api/signup -> {"token": "..."}"""
    return _request("POST", "/api/signup", json_body={"email": email, "password": password})


# ---------------------------------------------------------------------------
# Badges
# ---------------------------------------------------------------------------

def get_badges(token: str) -> APIResult:
    """GET /api/badges -> {"acquired": [...], "missing": [...]} (auth required)"""
    return _request("GET", "/api/badges", token=token)


# ---------------------------------------------------------------------------
# Actions (purchases, logins, ...)
# ---------------------------------------------------------------------------

def post_action(token: str, action: str, data: str) -> APIResult:
    """POST /api/actions -> {"action": "...", "certificates": [...]} (auth required)"""
    return _request("POST", "/api/actions", token=token, json_body={"action": action, "data": data})


def record_purchase(token: str, item_name: str, cost: str) -> APIResult:
    """Convenience wrapper for the 'buy_item' action the backend expects
    as a single pipe-delimited string: "item name|cost"."""
    return post_action(token, "buy_item", f"{item_name}|{cost}")


def record_login(token: str) -> APIResult:
    """Convenience wrapper for the 'login' action.

    NOTE: the backend's /api/login endpoint does NOT record this by itself
    (see README.md) -- login-streak badges only accumulate if the client
    explicitly posts a 'login' action after authenticating, so app.py calls
    this right after a successful login/signup.
    """
    return post_action(token, "login", "")
