# PR Recommendation

## Commit Message

```text
feat: implement SetLogPlus MVP logging flow
```

## PR Title

```text
SetLogPlus MVP: auth, group logs, camera upload, reactions
```

## PR Description

### Summary
- Built the MVP app structure for SetLogPlus using UIKit.
- Added Firebase Authentication, Firestore, and Storage integration.
- Implemented email/password login and sign-up.
- Added group creation, invite-code joining, group settings, member list, leave/delete flow.
- Implemented camera-based 3-second video recording and upload to selected groups.
- Added group feed with hourly log navigation, video preview cards, full video detail view, and sound control.
- Replaced chat with lightweight emoji reactions for a simpler MVP social interaction.
- Added profile features including nickname editing, group list, and logout.

### Why
SetLogPlus is designed as a lightweight short-video daily logging app, not a full SNS. The MVP focuses on recording, sharing, viewing, and reacting to short logs inside small groups.

### Main Changes
- `Auth/`: login and sign-up screens.
- `Feed/`: home/group feed, group settings, hourly log browsing, reactions.
- `Upload/`: camera recording, upload preview, group selection.
- `VideoDetail/`: full-screen video playback, loading state, sound toggle, reactions.
- `Profile/`: user profile, nickname update, group list, logout.
- `Services/`: Firebase repositories and video upload/audio helpers.
- `Models/`: user, group, post, reaction, notification models.
- `Shared/`: reusable UI/theme/time/video-preview helpers.

### Firebase Data Used
- `users/{uid}`
- `groups/{groupID}`
- `groups/{groupID}/members/{uid}`
- `posts/{postID}`
- `posts/{postID}/reactions/{uid}`
- Firebase Storage path: `videos/{groupID}/{uid}/{fileName}.mov`

### Test Notes
- Verified Xcode build with iOS Simulator target.
- Manual testing recommended:
  - Sign up/login
  - Create and join group by invite code
  - Record 3-second video
  - Upload to one or multiple groups
  - Open group feed and video detail
  - Toggle sound
  - Add/remove emoji reaction
  - Update nickname and logout

### Firebase Rules Reminder
Firestore rules should allow authenticated users to read/write their required MVP documents. For reactions:

```js
match /posts/{postID}/reactions/{userID} {
  allow read: if request.auth != null;
  allow write: if request.auth != null && request.auth.uid == userID;
}
```
