# iOS signing

CI already builds iOS. Without signing secrets it produces an **unsigned `.ipa`
plus the Xcode project**; with them it produces a **signed `.ipa`**. The workflow
detects which case it is on its own, so **no code change** is needed to switch.
Add four repository secrets and push.

> **You do not need a Mac.** Every step below runs in WSL. Apple's own
> documentation assumes Keychain Access, and an earlier version of this file
> repeated that assumption, which made it impossible to follow on this machine.
> A Certificate Signing Request is a standard PKCS#10 file, not an Apple format,
> and OpenSSL produces one Apple accepts.

---

## Sideloading, which still has a place

Even with a paid membership, `ios-unsigned-ipa` plus **Sideloadly** remains the
fastest way to get a build onto your own phone: no App Store Connect, no upload,
no processing wait. The difference enrolment makes is that the certificate now
lasts **a year instead of 7 days**.

```bash
gh run download -R Synthetic-Virus/Bounce-Ascent -n ios-unsigned-ipa
```

Use it for "does this fix work on the device". Use TestFlight when someone else
needs to play it, because sideloading only ever works for you.

---

## 1. Generate a key and a certificate request

In WSL, anywhere outside the repo (these are secrets, do not commit them):

```bash
mkdir -p ~/apple-signing && cd ~/apple-signing

openssl req -new -newkey rsa:2048 -nodes \
  -keyout ios_distribution.key \
  -out ios_distribution.csr \
  -subj "/emailAddress=YOUR_APPLE_ID_EMAIL/CN=YOUR NAME/C=US"
```

**The subject fields do not have to match anything.** You are not authenticated
by them: you are authenticated by being signed in to developer.apple.com when
you upload the request. Apple discards this subject and issues the certificate
with one of its own, along the lines of
`CN = Apple Distribution: Your Name (TEAMID)`. So the email here is inert
metadata and cannot mismatch your Apple ID later. Using your real Apple ID
address anyway just makes the file self-documenting when you renew in a year.

`ios_distribution.key` is your private key. It never leaves your machine and
Apple never sees it. **If you lose it the certificate becomes useless** and you
have to revoke and start again, so keep it somewhere you back up.

---

## 2. Get the certificate from Apple

At [developer.apple.com/account](https://developer.apple.com/account) →
Certificates, Identifiers & Profiles:

**Certificates → `+` → Apple Distribution.** Upload `ios_distribution.csr`.
Download the resulting `ios_distribution.cer`. Move it into `~/apple-signing`.

One Apple Distribution certificate covers both Ad Hoc and App Store builds, so
you only need this once. It expires after a year.

---

## 3. Combine them into a `.p12`

CI needs the certificate and its private key together, which is what a `.p12`
is:

```bash
cd ~/apple-signing

# Apple hands back DER; OpenSSL wants PEM to bundle it.
openssl x509 -inform DER -in ios_distribution.cer -out ios_distribution.pem

openssl pkcs12 -export -legacy \
  -inkey ios_distribution.key \
  -in ios_distribution.pem \
  -out Certificates.p12 \
  -name "Apple Distribution" \
  -passout pass:CHOOSE_A_PASSWORD
```

**`-legacy` is not optional.** OpenSSL 3, which is the default in Ubuntu 24.04,
encrypts `.p12` files with AES-256, and macOS `security import` on the CI runner
frequently refuses those. The failure surfaces as a wrong-password error during
the "Install certificate" step, which sends you looking in entirely the wrong
place. `-legacy` emits the older encryption the keychain accepts.

Verify before you go further, so a bad file is caught here rather than in CI:

```bash
openssl pkcs12 -in Certificates.p12 -legacy -nokeys -passin pass:CHOOSE_A_PASSWORD | \
  openssl x509 -noout -subject -dates
```

That should print an `Apple Distribution: ...` subject and a validity window
about a year out. If it errors, the `.p12` is wrong and CI will fail too.

---

## 4. Register the App ID

**Identifiers → `+` → App IDs → App.** The bundle ID must match what the build
already uses, and it is baked into every build produced so far:

```
org.virusgaming.bounceascent
```

Leave every capability unchecked. The game uses none of them, and each one you
enable becomes something Apple expects to see justified.

---

## 5. Create a provisioning profile

**Profiles → `+`.** Which type depends on what you are doing:

| Goal | Profile type |
|---|---|
| TestFlight or App Store | **App Store Connect** |
| Install directly on devices you own | **Ad Hoc** |

For an App Store release, pick **App Store Connect**. Select the App ID from
step 4 and the certificate from step 2, then download the
`.mobileprovision` into `~/apple-signing`.

Ad Hoc profiles only install on device UDIDs you have registered in the portal
beforehand, and adding a device later means regenerating the profile. That
limitation is the main reason TestFlight exists.

---

## 6. Add the four secrets

Both binaries go in base64, because a GitHub secret is text. `-w 0` keeps it on
one line, which matters:

```bash
cd ~/apple-signing
base64 -w 0 Certificates.p12 > p12.b64
base64 -w 0 *.mobileprovision > profile.b64
```

Then, from the repo:

```bash
gh secret set APPLE_CERT_P12 -R Synthetic-Virus/Bounce-Ascent < ~/apple-signing/p12.b64
gh secret set APPLE_PROVISIONING_PROFILE -R Synthetic-Virus/Bounce-Ascent < ~/apple-signing/profile.b64
gh secret set APPLE_CERT_PASSWORD -R Synthetic-Virus/Bounce-Ascent
gh secret set APPLE_TEAM_ID -R Synthetic-Virus/Bounce-Ascent
```

The last two prompt for the value. The Team ID is the ten-character string in
Membership details.

| Secret | Value |
|---|---|
| `APPLE_TEAM_ID` | ten-character Team ID |
| `APPLE_CERT_P12` | base64 of `Certificates.p12` |
| `APPLE_CERT_PASSWORD` | the password from step 3 |
| `APPLE_PROVISIONING_PROFILE` | base64 of the `.mobileprovision` |

Push anything, or run the workflow from the Actions tab. The iOS log will say
`Signing secrets present: producing a signed build.` and the artifact will be
named **`ios-signed-ipa`** instead of `ios-unsigned-ipa`.

---

## What the workflow does when the secrets exist

1. Creates a **throwaway keychain** in the runner temp directory and imports the
   certificate into it. The runner's default keychain is never touched.
2. Installs the provisioning profile.
3. Rewrites two fields in `export_presets.cfg`: the placeholder Team ID becomes
   the real one, and `export_project_only` flips to `false` so Godot archives
   through to an `.ipa` rather than stopping at the Xcode project.
4. Exports and uploads the artifact as `ios-signed-ipa`.

Those preset fields are patched **in CI only**, never committed, so the file in
git stays in its unsigned-friendly state and a contributor with no secrets still
gets a working build.

---

## Things that will bite you later

- **Certificates expire after a year**, provisioning profiles sooner. When iOS
  starts failing with a signing error long after it last worked, this is almost
  always why. Regenerate and replace the secrets. Keep `ios_distribution.key`,
  because renewal needs it.
- **The private key is the thing you cannot recover.** Apple can reissue a
  certificate; nobody can reissue your key.
- **Do not commit `~/apple-signing`.** It is deliberately outside the repo.

For everything beyond producing a signed build, see
[APP_STORE_RELEASE.md](APP_STORE_RELEASE.md).
