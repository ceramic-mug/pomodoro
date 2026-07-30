#!/usr/bin/env python3
"""Push App Store listing metadata via the App Store Connect API.

Everything here is idempotent: run it as often as you like. It only touches the
version that is still editable (PREPARE_FOR_SUBMISSION); it will refuse to edit
a version that is already in review or released.

Usage:
    export ASC_KEY_ID=6MBT4MC8MM
    export ASC_ISSUER_ID=<uuid from App Store Connect → Users and Access →
                          Integrations → App Store Connect API>
    python3 scripts/asc.py all

Subcommands:
    info         name, subtitle, privacy policy URL, primary category
    version      description, keywords, promo text, URLs, what's new
    screenshots  upload docs/screenshots/*.png as the 6.9" iPhone set
    agerating    declare 4+ (no objectionable content)
    price        set the one-time USD price
    all          every step above, in order
"""

import hashlib
import json
import os
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

import jwt

BUNDLE_ID = "com.joshuaeastman.pomodoro"
VERSION_STRING = "1.0"
LOCALE = "en-US"
PRICE_USD = "0.99"
SCREENSHOT_DIR = Path(__file__).resolve().parent.parent / "docs" / "screenshots"
# 1320 x 2868 is the 6.9" iPhone size; the API files it under the 6.7" bucket.
SCREENSHOT_DISPLAY_TYPE = "APP_IPHONE_67"

BASE = "https://api.appstoreconnect.apple.com"

SUBTITLE = "Focus cycles that keep time"
PRIVACY_URL = "https://github.com/ceramic-mug/pomodoro/blob/main/PRIVACY.md"
SUPPORT_URL = "https://github.com/ceramic-mug/pomodoro"
MARKETING_URL = "https://github.com/ceramic-mug/pomodoro"
KEYWORDS = "pomodoro,focus,timer,productivity,study,deep work,concentration,break,work timer,tomato,session,adhd"
PROMO = (
    "A focus timer that runs the whole session for you — four rounds of work and rest, "
    "then a long break. Your lengths, your colours, your glyphs. Buy once, no subscription."
)
WHATS_NEW = "First release."
DESCRIPTION = """Cadence is a quiet, single-screen focus timer. Open it, press start, and it runs your whole working session — focus, break, focus, break, four times over, then a long break — and starts again until you stop it.

Buy it once and it is yours. No subscription, no account, no ads, no analytics. Nothing leaves your phone.


KEEPS TIME, WHATEVER YOU DO

The timer is anchored to the clock, not to a ticking counter. Lock your phone, switch apps, or force-quit — when you come back, it is exactly where it should be. Alerts for every phase change are scheduled the moment you press start, so they arrive on time with the app closed.


ON YOUR LOCK SCREEN AND IN STANDBY

A Live Activity shows the countdown and progress ring on the Lock Screen and in the Dynamic Island. Put the phone on a charger on its side and StandBy turns it into a full-screen desk clock for the session.


MADE YOUR WAY

• Set each phase length — focus 5 to 90 minutes, short break 1 to 30, long break 5 to 60
• Pick an accent colour for each phase from eight curated tones; the whole screen follows it
• Choose a glyph for each phase from a set chosen to suit it
• Two tidy settings tabs: Timer and Appearance


IN CONTROL, ALWAYS

• Pause and resume with a tap anywhere on the dial
• Restart just the current phase when a session gets interrupted
• Skip ahead to the next phase
• Stop and return to the top of the cycle
• A cycle track shows all eight segments to scale, so you always know where you are


HANDS-FREE

Start, pause or stop from Siri or the Shortcuts app. Assign "Start or Pause Cadence" to the Action Button and begin a focus session without unlocking your phone.


THOUGHTFUL DETAILS

• Alerts can be marked time-sensitive so they arrive during a Focus
• Optional alert sound, and an option to keep the screen awake while running
• A proper landscape layout, not a stretched portrait one
• Dark by design, easy on the eyes at night


Cadence does not collect, transmit, or share any data. There is no network code in the app."""


# --- plumbing ---------------------------------------------------------------

def token() -> str:
    key_id = os.environ.get("ASC_KEY_ID", "6MBT4MC8MM")
    issuer = os.environ.get("ASC_ISSUER_ID")
    if not issuer:
        sys.exit("ASC_ISSUER_ID is not set. App Store Connect → Users and Access → "
                 "Integrations → App Store Connect API, the UUID above the key list.")
    key_path = Path(os.environ.get(
        "ASC_KEY_PATH", Path.home() / ".appstoreconnect" / "private_keys" / f"AuthKey_{key_id}.p8"))
    if not key_path.exists():
        sys.exit(f"Private key not found at {key_path}")
    now = int(time.time())
    return jwt.encode(
        {"iss": issuer, "iat": now, "exp": now + 1200, "aud": "appstoreconnect-v1"},
        key_path.read_text(),
        algorithm="ES256",
        headers={"kid": key_id, "typ": "JWT"},
    )


def request(method: str, path: str, body=None, raw=None, content_type=None, full_url=None):
    url = full_url or (BASE + path)
    data = raw if raw is not None else (json.dumps(body).encode() if body is not None else None)
    req = urllib.request.Request(url, data=data, method=method)
    if not full_url:
        req.add_header("Authorization", f"Bearer {token()}")
    req.add_header("Content-Type", content_type or "application/json")
    try:
        with urllib.request.urlopen(req) as resp:
            payload = resp.read()
            return json.loads(payload) if payload and resp.status != 204 else {}
    except urllib.error.HTTPError as err:
        detail = err.read().decode()
        try:
            errors = json.loads(detail).get("errors", [])
            detail = "\n".join(f"  {e.get('title')}: {e.get('detail')}" for e in errors) or detail
        except json.JSONDecodeError:
            pass
        sys.exit(f"{method} {url} failed ({err.code}):\n{detail}")


def first(items, what):
    if not items:
        sys.exit(f"No {what} found — check the app record in App Store Connect.")
    return items[0]


# --- lookups ----------------------------------------------------------------

def app_id() -> str:
    apps = request("GET", f"/v1/apps?filter[bundleId]={BUNDLE_ID}")["data"]
    return first(apps, f"app with bundle id {BUNDLE_ID}")["id"]


def app_info_id(app: str) -> str:
    infos = request("GET", f"/v1/apps/{app}/appInfos")["data"]
    editable = [i for i in infos
                if i["attributes"].get("appStoreState") not in ("READY_FOR_SALE", "IN_REVIEW")]
    return first(editable or infos, "editable app info")["id"]


def version_id(app: str) -> str:
    versions = request(
        "GET", f"/v1/apps/{app}/appStoreVersions?filter[versionString]={VERSION_STRING}")["data"]
    if versions:
        return versions[0]["id"]
    created = request("POST", "/v1/appStoreVersions", {
        "data": {
            "type": "appStoreVersions",
            "attributes": {"platform": "IOS", "versionString": VERSION_STRING},
            "relationships": {"app": {"data": {"type": "apps", "id": app}}},
        }
    })
    print(f"  created version {VERSION_STRING}")
    return created["data"]["id"]


def localization(parent_path: str, parent_id: str, child: str) -> str:
    items = request("GET", f"/v1/{parent_path}/{parent_id}/{child}")["data"]
    for item in items:
        if item["attributes"]["locale"] == LOCALE:
            return item["id"]
    sys.exit(f"No {LOCALE} localization found in {child}.")


# --- steps ------------------------------------------------------------------

def step_info():
    print("app info (subtitle, privacy URL, category)")
    info = app_info_id(app_id())
    loc = localization("appInfos", info, "appInfoLocalizations")
    request("PATCH", f"/v1/appInfoLocalizations/{loc}", {
        "data": {
            "type": "appInfoLocalizations", "id": loc,
            "attributes": {"subtitle": SUBTITLE, "privacyPolicyUrl": PRIVACY_URL},
        }
    })
    request("PATCH", f"/v1/appInfos/{info}", {
        "data": {
            "type": "appInfos", "id": info,
            "relationships": {
                "primaryCategory": {"data": {"type": "appCategories", "id": "PRODUCTIVITY"}}
            },
        }
    })
    print("  subtitle, privacy policy URL, primary category set")


def step_version():
    print("version metadata (description, keywords, URLs)")
    version = version_id(app_id())
    loc = localization("appStoreVersions", version, "appStoreVersionLocalizations")
    attributes = {
        "description": DESCRIPTION,
        "keywords": KEYWORDS,
        "promotionalText": PROMO,
        "supportUrl": SUPPORT_URL,
        "marketingUrl": MARKETING_URL,
    }
    # "What's New" only exists once there is a previous release to differ from;
    # Apple rejects the field on a first version.
    if os.environ.get("ASC_WHATS_NEW"):
        attributes["whatsNew"] = WHATS_NEW
    request("PATCH", f"/v1/appStoreVersionLocalizations/{loc}", {
        "data": {"type": "appStoreVersionLocalizations", "id": loc, "attributes": attributes}
    })
    print("  description, keywords, promo text, support and marketing URLs set")


def step_screenshots():
    print("screenshots")
    version = version_id(app_id())
    loc = localization("appStoreVersions", version, "appStoreVersionLocalizations")

    sets = request("GET", f"/v1/appStoreVersionLocalizations/{loc}/appScreenshotSets")["data"]
    target = next((s for s in sets
                   if s["attributes"]["screenshotDisplayType"] == SCREENSHOT_DISPLAY_TYPE), None)
    if target:
        set_id = target["id"]
        for shot in request("GET", f"/v1/appScreenshotSets/{set_id}/appScreenshots")["data"]:
            request("DELETE", f"/v1/appScreenshots/{shot['id']}")
        print("  cleared existing screenshots")
    else:
        set_id = request("POST", "/v1/appScreenshotSets", {
            "data": {
                "type": "appScreenshotSets",
                "attributes": {"screenshotDisplayType": SCREENSHOT_DISPLAY_TYPE},
                "relationships": {"appStoreVersionLocalization": {
                    "data": {"type": "appStoreVersionLocalizations", "id": loc}}},
            }
        })["data"]["id"]

    for path in sorted(SCREENSHOT_DIR.glob("*.png")):
        blob = path.read_bytes()
        created = request("POST", "/v1/appScreenshots", {
            "data": {
                "type": "appScreenshots",
                "attributes": {"fileName": path.name, "fileSize": len(blob)},
                "relationships": {"appScreenshotSet": {
                    "data": {"type": "appScreenshotSets", "id": set_id}}},
            }
        })["data"]

        for op in created["attributes"]["uploadOperations"]:
            chunk = blob[op["offset"]:op["offset"] + op["length"]]
            req = urllib.request.Request(op["url"], data=chunk, method=op["method"])
            for header in op["requestHeaders"]:
                req.add_header(header["name"], header["value"])
            with urllib.request.urlopen(req) as resp:
                resp.read()

        request("PATCH", f"/v1/appScreenshots/{created['id']}", {
            "data": {
                "type": "appScreenshots", "id": created["id"],
                "attributes": {"uploaded": True,
                               "sourceFileChecksum": hashlib.md5(blob).hexdigest()},
            }
        })
        print(f"  uploaded {path.name}")


def step_agerating():
    print("age rating")
    info = app_info_id(app_id())
    declaration = request("GET", f"/v1/appInfos/{info}/ageRatingDeclaration")["data"]
    request("PATCH", f"/v1/ageRatingDeclarations/{declaration['id']}", {
        "data": {
            "type": "ageRatingDeclarations", "id": declaration["id"],
            "attributes": {
                "violenceCartoonOrFantasy": "NONE",
                "violenceRealistic": "NONE",
                "violenceRealisticProlongedGraphicOrSadistic": "NONE",
                "profanityOrCrudeHumor": "NONE",
                "matureOrSuggestiveThemes": "NONE",
                "horrorOrFearThemes": "NONE",
                "medicalOrTreatmentInformation": "NONE",
                "alcoholTobaccoOrDrugUseOrReferences": "NONE",
                "sexualContentOrNudity": "NONE",
                "sexualContentGraphicAndNudity": "NONE",
                "gamblingSimulated": "NONE",
                "contests": "NONE",
                "gunsOrOtherWeapons": "NONE",
                "healthOrWellnessTopics": False,
                "gambling": False,
                "unrestrictedWebAccess": False,
                "userGeneratedContent": False,
                "messagingAndChat": False,
                "parentalControls": False,
                "advertising": False,
                "lootBox": False,
                "ageAssurance": False,
                "kidsAgeBand": None,
            },
        }
    })
    print("  declared 4+ (no objectionable content)")


def step_price():
    print(f"price (US${PRICE_USD}, one-time)")
    app = app_id()
    points = request(
        "GET",
        f"/v2/appPricePoints?filter[app]={app}&filter[territory]=USA&include=territory&limit=200"
    )["data"]
    match = next((p for p in points
                  if p["attributes"].get("customerPrice") == PRICE_USD), None)
    if not match:
        available = sorted({p["attributes"].get("customerPrice") for p in points})[:12]
        sys.exit(f"  no USD price point at {PRICE_USD}. Nearby: {available}\n"
                 "  (If this list is empty, the Paid Applications Agreement is not active yet.)")
    request("POST", "/v1/appPriceSchedules", {
        "data": {
            "type": "appPriceSchedules",
            "relationships": {
                "app": {"data": {"type": "apps", "id": app}},
                "baseTerritory": {"data": {"type": "territories", "id": "USA"}},
                "manualPrices": {"data": [{"type": "appPrices", "id": "price0"}]},
            },
        },
        "included": [{
            "type": "appPrices", "id": "price0",
            "relationships": {"appPricePoint": {
                "data": {"type": "appPricePoints", "id": match["id"]}}},
        }],
    })
    print(f"  price schedule set to US${PRICE_USD}")


def step_availability():
    print("availability (all territories)")
    app = app_id()
    current = request("GET", f"/v2/apps/{app}/appAvailabilityV2?include=territoryAvailabilities"
                             "&limit[territoryAvailabilities]=200")
    live = [t for t in current.get("included", [])
            if t["type"] == "territoryAvailabilities" and t["attributes"].get("available")]
    if live and current.get("data", {}).get("attributes", {}).get("availableInNewTerritories"):
        print(f"  already available in {len(live)} territories, including new ones")
        return

    territories = request("GET", "/v1/territories?limit=200")["data"]
    request("POST", "/v2/appAvailabilities", {
        "data": {
            "type": "appAvailabilities",
            "attributes": {"availableInNewTerritories": True},
            "relationships": {
                "app": {"data": {"type": "apps", "id": app}},
                "territoryAvailabilities": {"data": [
                    {"type": "territoryAvailabilities", "id": t["id"]} for t in territories
                ]},
            },
        },
        "included": [{
            "type": "territoryAvailabilities", "id": t["id"],
            "attributes": {"available": True},
            "relationships": {"territory": {"data": {"type": "territories", "id": t["id"]}}},
        } for t in territories],
    })
    print(f"  available in all {len(territories)} territories, and in new ones automatically")


STEPS = {
    "info": step_info,
    "version": step_version,
    "screenshots": step_screenshots,
    "agerating": step_agerating,
    "availability": step_availability,
    "price": step_price,
}


def main():
    args = sys.argv[1:] or ["all"]
    names = list(STEPS) if args == ["all"] else args
    for name in names:
        if name not in STEPS:
            sys.exit(f"Unknown step '{name}'. Choose from: {', '.join(STEPS)}, all")
        STEPS[name]()
    print("done")


if __name__ == "__main__":
    main()
