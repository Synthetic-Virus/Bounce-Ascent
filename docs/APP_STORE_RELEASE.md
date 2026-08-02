# Shipping Bounce Ascent to the App Store

Everything beyond producing a signed build. For the build itself see
[IOS_SIGNING.md](IOS_SIGNING.md).

Most of the work here is **not code**. The binary is the easy part; the metadata,
the legal URLs and the review are what actually take the time.

---

## Order of operations

Do these in order. Each one is blocked by the one above it.

1. Signing works and CI produces `ios-signed-ipa` ([IOS_SIGNING.md](IOS_SIGNING.md))
2. Host a privacy policy and a support page
3. Create the app record in App Store Connect
4. Upload a build and confirm it processes
5. Test it through TestFlight on a real device
6. Fill in metadata, screenshots, privacy and age rating
7. Submit for review

---

## 2. Two URLs you must have

Apple **requires** both. A missing privacy policy is an automatic rejection, and
it is the single most common reason a first submission bounces.

| Field | Requirement |
|---|---|
| Privacy policy URL | Publicly reachable, no login, states what you collect |
| Support URL | A page where a user can reach you |

You already host `virusgaming.org`, so both can live there. The privacy policy
can be genuinely short, because the honest version of this game's is short:

> Bounce Ascent does not collect, transmit or store any personal data. It has no
> analytics, no advertising, no accounts and no network connectivity. High
> scores and settings are stored only on your own device and are removed when
> you delete the app.

Confirm each claim before publishing it. As currently built all four are true:
the game makes no network calls, and `Scores` and `Settings` write only to
`user://`, which is the app sandbox.

---

## 3. The app record

At [appstoreconnect.apple.com](https://appstoreconnect.apple.com) → My Apps →
`+` → New App.

| Field | Value |
|---|---|
| Platform | iOS |
| Name | `Bounce Ascent` (must be unique across the whole store) |
| Primary language | English (U.S.) |
| Bundle ID | `org.virusgaming.bounceascent` |
| SKU | anything internal, e.g. `bounceascent` |
| User access | Full Access |

**Check the name is free before you get attached to it.** If `Bounce Ascent` is
taken you need a different store name, which does not have to match the name on
the home screen.

---

## 4. Export compliance

Every upload otherwise asks whether the app uses encryption. Answered once in
`Info.plist` via the export preset, so it never asks again:

```
ITSAppUsesNonExemptEncryption = false
```

This is accurate here: the game ships no encryption of its own, makes no HTTPS
calls, and the `encrypt_pck` option is off in `export_presets.cfg`. Do not set
this to false if any of that changes.

---

## 5. Screenshots

The most tedious requirement, and it needs a real device or simulator.

App Store Connect tells you exactly which display sizes it wants, and Apple
changes the list from time to time, so **read the sizes in the upload dialog
rather than trusting any number written here.** As of writing you need a set for
the largest iPhone display and Apple scales the rest.

Practical notes for this game specifically:

- Take them on device with the **pause screen closed** and the HUD live.
- Good candidates: a PERFECT landing with a high combo, the death line closing,
  a screen full of solid blocks late in a run, and the track select.
- Screenshots must show the **actual app**. Mocked-up marketing images with
  invented UI are a rejection under Guideline 2.3.

---

## 6. App privacy

App Store Connect → your app → App Privacy.

Answer **"Data Not Collected"**. That is the honest answer and it is unusually
easy to defend here: no network layer, no SDKs, no third-party libraries. It
also means you skip the entire data-types questionnaire.

Godot already ships `PrivacyInfo.xcprivacy` in the built app, which is Apple's
required-reason API manifest. Confirmed present in the `.ipa`.

---

## 7. Age rating

Answer the questionnaire honestly. With no violence, no gambling, no user
content, no web access and no ads, this lands at **4+**.

---

## 8. Metadata

| Field | Notes |
|---|---|
| Subtitle | 30 characters. Something like `Land on the beat` |
| Promotional text | 170 chars, changeable without review |
| Description | What it is and how it plays. Lead with the one idea: timing decides how high you climb |
| Keywords | 100 chars total, comma separated, no spaces after commas |
| Category | Primary **Games**, subcategories **Music** and **Arcade** |
| Copyright | `2026 Andrew Alexander` |

Write the description from the player's side. The single most important sentence
is the one that explains that a perfectly timed jump climbs two platforms
instead of one, because that rule is not discoverable by playing and it is the
whole game.

---

## 9. Upload and TestFlight

CI can upload for you. It needs three secrets **beyond** the four signing ones.

App Store Connect → Users and Access → Integrations → App Store Connect API →
`+`, with the **App Manager** role:

| Secret | Where it comes from |
|---|---|
| `APPSTORE_ISSUER_ID` | the issuer UUID shown above the key list |
| `APPSTORE_KEY_ID` | the ten-character key ID in the row |
| `APPSTORE_PRIVATE_KEY` | base64 of the downloaded `.p8` |

**The `.p8` downloads exactly once and can never be downloaded again.** Save it
before you close the page. If you lose it, revoke the key and make a new one.

```bash
base64 -w 0 AuthKey_XXXXXXXXXX.p8 > p8.b64
gh secret set APPSTORE_PRIVATE_KEY -R Synthetic-Virus/Bounce-Ascent < p8.b64
gh secret set APPSTORE_ISSUER_ID -R Synthetic-Virus/Bounce-Ascent
gh secret set APPSTORE_KEY_ID -R Synthetic-Virus/Bounce-Ascent
```

Then upload from Actions → Build → **Run workflow**, ticking
**"Upload the signed build to TestFlight"**.

It is deliberately manual and never fires on a push. An upload permanently
consumes a build number, so an automatic upload on every commit would burn
numbers, notify testers about work in progress, and publish things you did not
mean to publish. CI stamps `CFBundleVersion` from the run number so it is always
unique, and validates before uploading, because validation is free and an upload
is not.

**Do not skip the TestFlight step.** A build that works sideloaded can still
fail from App Store Connect, because the App Store profile, entitlements and
provisioning differ from the Ad Hoc path. Finding that out during review costs
days; finding it in TestFlight costs minutes.

---

## 10. Review

Expect a first submission to take a couple of rounds. The rejections most likely
to apply to this app:

- **Missing or unreachable privacy policy.** The most common first rejection.
- **Guideline 2.1, crashes on the reviewer's device.** They test on real
  hardware, sometimes older than yours.
- **Guideline 4.2, minimum functionality.** Aimed at trivial apps. Three tracks,
  five platform types, scoring, calibration and settings should clear it, but a
  game that looks like a tech demo is at risk.
- **Screenshots that do not match the app.**

There is no fast lane. Answer in Resolution Center, fix, resubmit.

---

## What is already done

- `PrivacyInfo.xcprivacy` ships in the build (Godot provides it)
- App icon is square and fully opaque, which Apple requires and which the
  original rounded icon would have failed
- Bundle ID `org.virusgaming.bounceascent` is stable across every build produced
- Minimum iOS 14.0, arm64, portrait only
- No network code, no analytics, no third-party SDKs

## What only you can do

- Host the privacy policy and support pages
- Everything inside the Apple portals: App ID, certificate, profile, app record
- Screenshots from a real device
- Write the store description
- Respond to review
