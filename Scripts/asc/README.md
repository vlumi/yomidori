# App Store Connect tooling

The listing and the screenshots from the repo, never from the ASC UI:
`listing.json` is the single source of the listing text, `shots.json` of the
screenshots (what each shows and the demo arguments that stage it). Edit here,
sync with one command.

## Setup (once)

Credentials are the release lane's: `Scripts/.asc-config` (Key ID + Issuer ID)
with the `.p8` in `~/.appstoreconnect/private_keys/` — nothing new. The Python
side runs in a venv that `run.sh` makes on first use (Homebrew's Python is
externally-managed), so the Make targets are one step.

## Use

```sh
make asc-listing              # dry run: what differs from ASC
make asc-listing-apply        # write the listing text (both platforms, every locale)

make shots PLATFORM=iphone    # capture the screenshots (see SCREENSHOTS.md)
make asc-screenshots          # dry run: the upload plan from shots/
make asc-screenshots-apply    # replace each set and upload, in store order
```

The sync writes to every *editable* version (Prepare for Submission, rejected);
a version in review or live is skipped and said so.

## By hand, in App Store Connect

What the API tooling does not cover, set once on the record:

- **Categories**: Education (primary), Reference (secondary).
- **Age rating**: none of the questionnaire's content; 4+.
- **App Privacy**: *Data Not Collected* — the camera is used on the device
  and nothing is uploaded; iCloud sync is the reader's own account. The
  privacy policy URL is in `listing.json`.
- **Pricing and availability**: free, all territories.
- **Review notes**: how to see the app without a book — paste Japanese text on
  the Read tab (the Mac) or give it a screenshot (iOS); a demo of fixed data
  is built in for screenshots, not for review.
