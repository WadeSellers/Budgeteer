# App Store Connect — Privacy Nutrition Labels

Reference for filling out the App Privacy section in App Store Connect.

## Do you collect data?

**Yes** — but only transiently via a third-party API.

---

## Data Types to Declare

### 1. Financial Info → Purchases

- **Is this data linked to the user's identity?** No
- **Is this data used to track the user?** No
- **Purposes:** App Functionality
- **Notes:** Purchase amounts, descriptions, and categories are stored locally on the user's device via SwiftData. This data never leaves the device except as described below.

### 2. Other Data → Other Data Types

- **Is this data linked to the user's identity?** No
- **Is this data used to track the user?** No
- **Purposes:** App Functionality
- **Notes:** When the user records a purchase by voice, the text transcript (e.g., "twelve fifty at Trader Joe's") is sent to Anthropic's Claude API for parsing. The text is processed transiently and is not retained by Anthropic. No user identifiers, device IDs, or audio are included in the request.

---

## Data NOT Collected

These categories should all be marked as **not collected**:

- Contact Info (name, email, phone, address)
- Health & Fitness
- Browsing History
- Search History
- Identifiers (user ID, device ID)
- Usage Data (product interaction, advertising data)
- Diagnostics (crash data, performance data)
- Location
- Contacts
- Photos or Videos
- Audio Data (microphone is accessed for on-device speech recognition only — audio is never recorded, stored, or transmitted)
- Sensitive Info

---

## Summary for the App Store Listing

| Category | Collected | Linked | Tracking |
|----------|-----------|--------|----------|
| Purchases (Financial Info) | On-device only | No | No |
| Other Data (AI text processing) | Transiently | No | No |
| Everything else | Not collected | — | — |
