# Turning on iOS signing

CI already builds iOS. Without signing secrets it produces an **unsigned Xcode
project**; with them it produces a **signed `.ipa`**. The workflow detects which
case it is on its own, so **no code changes are needed** when your Apple
Developer enrolment completes. Add four repository secrets and push.

---

## What you need from Apple

Once the enrolment is approved, at
[developer.apple.com/account](https://developer.apple.com/account):

**1. Team ID.** Membership details, a ten-character string like `A1B2C3D4E5`.

**2. A distribution certificate.** Certificates, Identifiers & Profiles →
Certificates → `+` → *Apple Distribution*. You upload a Certificate Signing
Request, which you generate on a Mac in Keychain Access
(*Certificate Assistant → Request a Certificate From a Certificate Authority*,
saved to disk). Download the resulting `.cer` and double-click to install it.

**3. An App ID.** Identifiers → `+` → *App IDs* → *App*. The bundle ID must
match the one already in `export_presets.cfg`:

```
org.virusgaming.bounceascent
```

Change it in both places if you want a different one.

**4. A provisioning profile.** Profiles → `+`. Pick *Ad Hoc* to install on
devices you register, or *App Store* to upload to TestFlight. Select the App ID
and certificate from above, then download the `.mobileprovision`.

---

## Exporting the certificate

The certificate is only useful to CI together with its private key, which means
a `.p12`:

1. Keychain Access → *My Certificates*
2. Right-click the *Apple Distribution* certificate → **Export**
3. Save as `.p12` and set a password (any password; you will store it as a
   secret)

---

## The four secrets

Settings → Secrets and variables → Actions → *New repository secret*.

Both binary files go in base64-encoded, because a GitHub secret is text:

```bash
base64 -i Certificates.p12 | pbcopy          # -> APPLE_CERT_P12
base64 -i BounceAscent.mobileprovision | pbcopy   # -> APPLE_PROVISIONING_PROFILE
```

On Linux or WSL use `base64 -w 0 <file>` instead, so the output is a single
line with no wrapping.

| Secret | Value |
|---|---|
| `APPLE_TEAM_ID` | the ten-character Team ID |
| `APPLE_CERT_P12` | base64 of the `.p12` |
| `APPLE_CERT_PASSWORD` | the password you set when exporting the `.p12` |
| `APPLE_PROVISIONING_PROFILE` | base64 of the `.mobileprovision` |

Push anything, or run the workflow manually from the Actions tab. The iOS job
log will say `Signing secrets present: producing a signed build.`

---

## What the workflow does when they exist

1. Creates a **throwaway keychain** in the runner temp directory and imports the
   certificate into it. The runner's default keychain is never touched.
2. Installs the provisioning profile.
3. Rewrites two fields in `export_presets.cfg`: the placeholder Team ID becomes
   the real one, and `export_project_only` flips to `false` so Godot archives
   through to an `.ipa` instead of stopping at the Xcode project.
4. Exports and uploads the artifact as `ios-signed-ipa`.

Those two preset fields are patched **in CI only**, not committed. The file in
git stays in its unsigned-friendly state so a contributor without secrets still
gets a working build.

---

## Notes worth knowing before you spend money

- **macOS runners bill at 10x** the Linux minute rate. That is why the iOS job
  is independent and `continue-on-error`: it never blocks or slows the Windows
  and Android builds, which run free on Linux.
- **Certificates expire after a year** and provisioning profiles sooner. When
  iOS starts failing with a signing error long after it last worked, this is
  almost always why. Re-export and replace the secrets.
- **Ad Hoc profiles only install on registered devices.** You must add each
  device's UDID in the portal and regenerate the profile. For wider testing,
  use an App Store profile and upload to TestFlight.
- **TestFlight upload is a further step** beyond producing an `.ipa`: it needs
  an App Store Connect API key and an `xcrun altool`/`notarytool` call. Say the
  word once signing works and I will add it.

---

## Current state

`export_presets.cfg` ships a placeholder Team ID of `0000000000`. Godot
validates that field and refuses the iOS export outright without it, even for an
unsigned build, so the placeholder is what lets CI produce anything at all
before enrolment completes.
