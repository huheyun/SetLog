# SetLogPlus 최종 보고서

## 1. 프로젝트 개요

SetLogPlus는 Setlog에서 영감을 받은 iOS 기반 짧은 영상 일상 기록 앱이다. 기존 SNS처럼 팔로우, 댓글, 채팅, 탐색 피드가 중심인 앱이 아니라, 가까운 사람들과 구성한 그룹 안에서 매우 짧은 영상을 기록하고 확인하는 데 초점을 맞추었다.

이 프로젝트의 핵심 개선점은 두 가지이다. 첫째, 사용자가 짧은 영상을 더 큰 상세 화면에서 볼 수 있도록 한다. 둘째, 짧은 영상의 소리를 명확하게 들을 수 있도록 한다. 이를 통해 단순한 썸네일형 피드보다 더 나은 영상 확인 경험을 제공한다.

MVP는 1개월 학생 프로젝트 수준에서 현실적으로 구현 가능한 범위를 기준으로 설계했다. 따라서 복잡한 SNS 기능은 제외하고, 로그인, 그룹, 촬영, 업로드, 피드, 상세 보기, 이모지 반응, 프로필 기능을 중심으로 구성했다.

## 2. 개발 환경 및 기술 스택

- 개발 언어: Swift
- UI 프레임워크: UIKit
- 인증: Firebase Authentication
- 데이터베이스: Cloud Firestore
- 파일 저장소: Firebase Storage
- 카메라/영상 처리: AVFoundation
- 영상 재생: AVKit
- 개발 도구: Xcode

현재 프로젝트는 UIKit 기반으로 구성되어 있으며, 화면은 대부분 코드 기반 ViewController로 작성되었다. Firebase는 인증, 메타데이터 저장, 영상 파일 업로드에 사용된다.

## 3. MVP 주요 기능

SetLogPlus MVP에서 구현한 주요 기능은 다음과 같다.

- 이메일/비밀번호 회원가입
- 이메일/비밀번호 로그인
- 로그아웃 전까지 로그인 상태 유지
- 그룹 생성
- 초대 코드로 그룹 참여
- 그룹 멤버 목록 확인
- 그룹장/그룹원 역할 구분
- 그룹원은 그룹 나가기
- 그룹장은 그룹 삭제
- 실제 카메라를 통한 짧은 영상 촬영
- 약 3초 촬영 제한
- 촬영 진행 바 표시
- 카메라 전환, 플래시, 배율 기능
- 촬영 후 여러 그룹에 업로드
- 업로드 전 소리 포함/무음 선택
- 그룹 피드에서 멤버별 영상 카드 확인
- 영상이 올라온 시간대만 이동
- 영상 상세 화면에서 큰 화면 재생
- 상세 화면 소리 on/off
- 영상별 이모지 반응
- 프로필 닉네임 수정
- 내가 속한 그룹 목록 확인

## 4. 화면 구성

### 로그인 화면

사용자가 이메일과 비밀번호를 입력해 로그인하는 화면이다. Firebase Authentication과 연결되어 있으며, 로그인 성공 시 메인 화면으로 이동한다.

### 회원가입 화면

새 사용자가 이메일, 비밀번호, 닉네임을 입력해 계정을 생성한다. 계정 생성 후 Firestore의 `users` 컬렉션에 기본 사용자 정보를 저장한다.

### 홈 화면

사용자가 속한 그룹 목록을 보여준다. 여기서 그룹을 새로 만들거나, 초대 코드를 입력해 기존 그룹에 참여할 수 있다. 하단의 카메라/로그 전환 버튼을 통해 촬영 화면과 로그 화면을 오갈 수 있다.

### 그룹 피드 화면

선택한 그룹의 로그를 보여주는 핵심 화면이다. 멤버별로 영상 카드가 배치되며, 특정 시간대에 멤버가 업로드한 영상이 있으면 미리보기가 표시된다. 영상이 없는 경우에는 비어 있는 카드가 표시된다.

상단의 dot은 영상이 업로드된 시간대를 나타낸다. 사용자는 좌우 탭을 통해 업로드된 시간대 사이를 이동할 수 있다.

### 카메라 화면

실제 카메라와 연결된 촬영 화면이다. 사용자는 즉시 짧은 영상을 촬영할 수 있다. 사진첩에서 영상을 선택하는 기능은 의도적으로 제외했다. SetLogPlus의 목적이 "지금 바로 기록하기"이기 때문이다.

### 업로드 그룹 선택 화면

촬영이 끝난 후 나타나는 화면이다. 사용자는 영상을 확인한 뒤 업로드할 그룹을 선택한다. 여러 그룹에 동시에 올릴 수 있고, 업로드 전 소리 포함 여부를 선택할 수 있다.

### 영상 상세 화면

그룹 피드에서 영상을 탭하거나 길게 누르면 이동하는 화면이다. 영상이 전체 화면에 가깝게 표시되며, 소리 버튼을 통해 음소거 여부를 조절할 수 있다. 작성자, 시간, 반응 정보도 함께 표시된다.

### 프로필 화면

사용자의 닉네임, 이메일, 참여 중인 그룹 목록, 로그아웃 기능을 제공한다. 닉네임은 Firestore의 사용자 정보와 Firebase Auth 프로필에 반영된다.

## 5. 프로젝트 폴더 구조

현재 프로젝트는 기능과 역할에 따라 다음과 같이 구성되어 있다.

```text
SetLogPlus/
  App/
  Auth/
  Feed/
  Models/
  Profile/
  Services/
  Shared/
  Upload/
  VideoDetail/
```

### App

`AppRouter.swift`가 포함되어 있다. 로그인 화면, 메인 화면, 카메라 화면 전환처럼 앱 전체에서 사용하는 이동 로직을 담당한다.

### Auth

`LoginViewController.swift`, `SignUpViewController.swift`가 포함된다. Firebase Authentication을 사용한 로그인/회원가입 UI를 담당한다.

### Feed

`FeedViewController.swift`, `GroupFeedViewController.swift`, `GroupSettingsViewController.swift`가 포함된다. 홈 화면, 그룹 피드, 그룹 설정 화면을 담당한다.

### Models

앱에서 사용하는 데이터 모델이 위치한다.

- `AppUser`
- `Group`
- `GroupMember`
- `Post`
- `PostReaction`
- `LogNotification`

모델은 복잡한 상속 구조 없이 단순한 Swift struct로 구성했다.

### Profile

`ProfileViewController.swift`가 포함된다. 사용자 정보 표시, 닉네임 수정, 그룹 목록, 로그아웃을 담당한다.

### Services

Firebase와 영상 처리 로직을 ViewController에서 분리하기 위한 계층이다.

- `AuthService`
- `UserRepository`
- `GroupRepository`
- `PostRepository`
- `ReactionRepository`
- `PostUploadService`
- `VideoStorageService`
- `VideoAudioService`
- `NotificationService`

### Shared

여러 화면에서 재사용되는 UI 컴포넌트와 유틸리티가 위치한다.

- `AppTheme`
- `BottomModeControl`
- `HourSlot`
- `IconCircleButton`
- `PlaceholderView`
- `PrimaryButton`
- `ReactionFormatter`
- `ToastView`
- `VideoPreviewView`

### Upload

`UploadViewController.swift`, `UploadGroupSelectionViewController.swift`가 포함된다. 카메라 촬영과 업로드 그룹 선택 흐름을 담당한다.

### VideoDetail

`VideoDetailViewController.swift`가 포함된다. 큰 화면 영상 재생, 로딩 상태, 소리 버튼, 반응 버튼을 담당한다.

## 6. Firebase 데이터 구조

### users

```text
users/{uid}
```

사용자 기본 정보를 저장한다.

```js
{
  uid: "...",
  email: "...",
  displayName: "...",
  createdAt: ...
}
```

### groups

```text
groups/{groupID}
```

그룹 정보를 저장한다.

```js
{
  id: "...",
  name: "...",
  ownerID: "...",
  inviteCode: "...",
  createdAt: ...
}
```

### group members

```text
groups/{groupID}/members/{uid}
```

그룹 멤버와 역할 정보를 저장한다.

```js
{
  uid: "...",
  displayName: "...",
  role: "owner" | "member",
  joinedAt: ...
}
```

### posts

```text
posts/{postID}
```

영상 메타데이터를 저장한다.

```js
{
  id: "...",
  groupID: "...",
  authorID: "...",
  authorName: "...",
  caption: "...",
  videoURL: "...",
  storagePath: "...",
  durationSeconds: 3,
  hourKey: "...",
  includesAudio: true,
  createdAt: ...
}
```

### reactions

```text
posts/{postID}/reactions/{uid}
```

영상별 사용자 반응을 저장한다. 한 사용자는 한 영상에 하나의 반응만 남길 수 있다.

```js
{
  postID: "...",
  userID: "...",
  userName: "...",
  emoji: "😍",
  createdAt: ...
}
```

### Firebase Storage

영상 파일은 Firebase Storage에 저장된다.

```text
videos/{groupID}/{uid}/{fileName}.mov
```

Firestore에는 Storage 파일의 다운로드 URL과 경로를 메타데이터로 저장한다.

## 7. 핵심 코드 설명

### AuthService

`AuthService`는 Firebase Authentication 관련 기능을 감싼 서비스 클래스이다. 로그인, 회원가입, 로그아웃을 담당한다. ViewController가 Firebase Auth API를 직접 많이 다루지 않도록 하여 코드 구조를 단순하게 유지한다.

### GroupRepository

`GroupRepository`는 그룹 생성, 그룹 조회, 초대 코드로 그룹 참여, 멤버 조회, 그룹 나가기, 그룹 삭제 등을 담당한다. 그룹 데이터는 `groups` 컬렉션에 저장되고, 멤버 데이터는 각 그룹 문서 아래의 `members` 서브컬렉션에 저장된다.

### PostUploadService

`PostUploadService`는 영상 업로드 전체 흐름을 조율한다. 촬영된 영상 파일을 Firebase Storage에 업로드하고, 업로드가 성공하면 Firestore의 `posts` 컬렉션에 영상 메타데이터를 저장한다.

### VideoStorageService

`VideoStorageService`는 Firebase Storage 업로드를 담당한다. 업로드가 성공하면 다운로드 URL과 Storage 경로를 반환한다.

### VideoAudioService

`VideoAudioService`는 사용자가 업로드 전 무음을 선택했을 때 영상에서 오디오를 제거한 복사본을 생성한다. 이 기능 덕분에 촬영 시점이 아니라 업로드 시점에 소리 포함 여부를 결정할 수 있다.

### UploadViewController

`UploadViewController`는 실제 카메라 촬영 화면이다. AVFoundation을 사용해 카메라 미리보기를 표시하고, 약 3초 동안 영상을 녹화한다. 촬영 중에는 진행 바가 표시되어 사용자가 촬영 완료 시점을 예상할 수 있다.

### UploadGroupSelectionViewController

촬영 완료 후 업로드할 그룹을 선택하는 화면이다. 사용자는 여러 그룹을 선택할 수 있으며, 소리 포함 여부를 토글할 수 있다. 업로드 성공 후에는 선택한 그룹 피드에서 영상을 확인할 수 있다.

### GroupFeedViewController

그룹 피드의 핵심 ViewController이다. 그룹 멤버, 업로드된 영상, 이모지 반응을 불러와 멤버별 영상 카드를 구성한다. 시간대 이동은 실제 업로드가 있는 시간만 가능하도록 하여 빈 시간대를 계속 탐색해야 하는 불편함을 줄였다.

### VideoDetailViewController

영상 상세 화면을 담당한다. `AVPlayerViewController`를 사용해 영상을 큰 화면으로 재생하고, 로딩 상태를 표시한다. 사용자는 소리 버튼으로 음소거를 전환할 수 있으며, 이모지 반응도 남길 수 있다.

### ReactionRepository

`ReactionRepository`는 영상별 이모지 반응을 Firestore에 저장하고 불러오는 역할을 한다. 반응은 `posts/{postID}/reactions/{uid}` 경로에 저장된다. 같은 이모지를 다시 선택하면 반응이 삭제되고, 다른 이모지를 선택하면 기존 반응이 업데이트된다.

### ReactionFormatter

`ReactionFormatter`는 여러 반응을 화면에 표시하기 좋은 문자열로 바꾼다. 예를 들어 다음과 같은 형태로 표시한다.

```text
😍 2  🔥 1
```

피드에서는 최대 2개, 상세 화면에서는 최대 3개 정도만 보여주어 UI가 복잡해지지 않게 했다.

## 8. 채팅 대신 이모지 반응을 선택한 이유

초기에는 그룹별 채팅 기능도 고려했다. 그러나 채팅은 실시간 메시지 동기화, 키보드 UX, 메시지 정렬, 읽음 상태, 알림 등 추가로 해결해야 할 문제가 많다. SetLogPlus의 핵심은 대화가 아니라 "짧은 영상 기록"이다.

따라서 MVP에서는 채팅을 제외하고 이모지 반응으로 대체했다. 이 방식은 사용자가 영상에 가볍게 반응할 수 있게 하면서도 앱의 복잡도를 낮춘다. 또한 SetLogPlus가 추구하는 간단하고 빠른 기록 경험과 더 잘 어울린다.

## 9. Firebase 보안 규칙 예시

개발 및 테스트 초기에는 넓은 권한을 사용할 수 있지만, 최종적으로는 인증된 사용자 기준의 규칙이 필요하다.

Firestore 예시:

```js
rules_version = '2';

service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userID} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userID;
    }

    match /groups/{groupID} {
      allow read, write: if request.auth != null;

      match /members/{userID} {
        allow read, write: if request.auth != null;
      }
    }

    match /posts/{postID} {
      allow read, write: if request.auth != null;

      match /reactions/{userID} {
        allow read: if request.auth != null;
        allow write: if request.auth != null && request.auth.uid == userID;
      }
    }
  }
}
```

Storage 예시:

```js
rules_version = '2';

service firebase.storage {
  match /b/{bucket}/o {
    match /videos/{groupID}/{userID}/{fileName} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userID;
    }
  }
}
```

## 10. 테스트 체크리스트

최종 테스트에서는 다음 항목을 확인해야 한다.

- 회원가입 성공
- 로그인 성공
- 앱 재실행 후 로그인 유지
- 그룹 생성
- 초대 코드 복사
- 초대 코드로 그룹 참여
- 그룹 멤버 목록 확인
- 카메라 촬영
- 3초 제한 동작 확인
- 플래시/배율/카메라 전환 버튼 확인
- 그룹 선택 후 업로드
- 여러 그룹 동시 업로드
- 무음 업로드 확인
- 그룹 피드에서 영상 표시 확인
- 영상 상세 화면 진입
- 상세 화면 소리 재생 확인
- 이모지 반응 추가
- 이모지 반응 취소
- 닉네임 변경
- 로그아웃
- 그룹원 나가기
- 그룹장 그룹 삭제

## 11. 한계점 및 개선 방향

현재 MVP에는 몇 가지 한계가 있다.

- 영상 압축 기능이 부족해 네트워크 상태에 따라 업로드가 느릴 수 있다.
- Firebase 규칙은 실제 서비스 수준으로 더 정교하게 다듬어야 한다.
- 이모지 반응 선택 UI는 현재 기본 액션 시트 기반이므로, 추후 커스텀 바텀시트로 개선할 수 있다.
- 푸시 알림은 아직 구현하지 않았다.
- 썸네일 생성 및 캐싱을 추가하면 피드 성능을 더 개선할 수 있다.
- 그룹 멤버 권한 검증을 Firestore Rules 수준에서 더 엄격히 적용할 필요가 있다.

## 12. 결론

SetLogPlus는 짧은 영상 일상 기록이라는 핵심 목적에 맞춰 MVP를 구성했다. 로그인, 그룹, 촬영, 업로드, 피드, 상세 보기, 소리 재생, 이모지 반응까지 주요 흐름이 연결되어 있으며, 채팅처럼 무거운 기능은 제외해 앱의 방향성을 단순하게 유지했다.

결과적으로 SetLogPlus는 "가까운 그룹 안에서 오늘의 짧은 순간을 영상으로 남기고, 가볍게 확인하고 반응하는 앱"이라는 목표를 달성하는 MVP 형태로 구현되었다.
