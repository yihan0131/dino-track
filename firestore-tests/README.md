# Firestore rules tests

Runs `../firestore.rules` on the local Firestore emulator (never the live
database) and checks two things:

- **app** tests: every read/write Dino Track really makes still works.
- **attack** tests: holes in the old rules (making yourself admin, editing
  other users' points or challenge progress, reading goals logged out) are
  blocked.

```bash
npm install
npm test
```

Needs Node and the Firebase CLI. The emulator needs Java 21 for current
firebase-tools; with Java 17 use `npx firebase-tools@13.29.1` in the script.
