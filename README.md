## 설명

### 요약
- UIKit 기반으로 SetLogPlus MVP 앱 구조를 구현했습니다.
- Firebase Authentication, Firestore, Storage를 연동했습니다.
- 이메일/비밀번호 로그인 및 회원가입 기능을 구현했습니다.
- 그룹 생성, 초대 코드로 참여, 그룹 설정, 멤버 목록, 그룹 나가기/삭제 흐름을 추가했습니다.
- 카메라 기반 3초 영상 촬영과 선택한 그룹으로 업로드하는 기능을 구현했습니다.
- 시간대별 로그 이동, 영상 미리보기 카드, 전체 영상 상세 보기, 소리 제어가 가능한 그룹 피드를 추가했습니다.
- MVP 소셜 기능을 단순하게 유지하기 위해 채팅 대신 가벼운 이모지 반응 기능으로 대체했습니다.
- 닉네임 수정, 그룹 목록, 로그아웃을 포함한 프로필 기능을 추가했습니다.

### 이유
SetLogPlus는 전체 SNS가 아니라, 가벼운 짧은 영상 일상 기록 앱으로 설계되었습니다. MVP는 작은 그룹 안에서 짧은 로그를 촬영하고, 공유하고, 확인하고, 반응하는 흐름에 집중합니다.

### 주요 변경 사항
- `Auth/`: 로그인 및 회원가입 화면
- `Feed/`: 홈/그룹 피드, 그룹 설정, 시간대별 로그 탐색, 반응 기능
- `Upload/`: 카메라 촬영, 업로드 미리보기, 그룹 선택
- `VideoDetail/`: 전체 화면에 가까운 영상 재생, 로딩 상태, 소리 토글, 반응 기능
- `Profile/`: 사용자 프로필, 닉네임 수정, 그룹 목록, 로그아웃
- `Services/`: Firebase 저장소 계층 및 영상 업로드/오디오 처리 헬퍼
- `Models/`: 사용자, 그룹, 게시물, 반응, 알림 모델
- `Shared/`: 재사용 가능한 UI, 테마, 시간, 영상 미리보기 헬퍼

### 사용한 Firebase 데이터
- `users/{uid}`
- `groups/{groupID}`
- `groups/{groupID}/members/{uid}`
- `posts/{postID}`
- `posts/{postID}/reactions/{uid}`
- Firebase Storage 경로: `videos/{groupID}/{uid}/{fileName}.mov`

### 테스트 참고 사항
- iOS Simulator 타깃으로 Xcode 빌드를 확인했습니다.
- 권장 수동 테스트:
  - 회원가입/로그인
  - 그룹 생성 및 초대 코드로 참여
  - 3초 영상 촬영
  - 하나 또는 여러 그룹에 업로드
  - 그룹 피드 및 영상 상세 화면 열기
  - 소리 토글
  - 이모지 반응 추가/삭제
  - 닉네임 수정 및 로그아웃

## Firebase 서버 설정

서버 측 설정 파일은 저장소 루트에 있습니다: `firebase.json`, `.firebaserc`(기본 프로젝트 `setlogplus`), `firestore.rules`, `storage.rules`, `firestore.indexes.json`, `functions/`.

1. **GoogleService-Info.plist**: Firebase 콘솔 > 프로젝트 설정 > iOS 앱에서 내려받아 `SetLogPlus/` 폴더에 넣습니다. 이 파일은 `.gitignore`에 포함되어 커밋되지 않습니다.
2. **요금제**: Cloud Functions(2세대) 배포에는 **Blaze(종량제) 요금제**가 필요합니다.
3. **배포** (Firebase CLI 로그인 후 저장소 루트에서):
   ```bash
   cd functions && npm install && cd ..
   firebase deploy --only functions,firestore:rules,storage
   ```
   - `storage.rules`는 그룹 멤버 확인을 위해 Firestore를 교차 조회(`firestore.get`)합니다. 첫 배포 시 Storage 서비스 계정에 권한을 부여할지 묻는 안내가 나오면 승인해야 합니다.
4. **Cloud Function `onGroupDeleted`**: `groups/{groupId}` 문서가 삭제되면 해당 그룹의 `posts`(및 `reactions` 하위 컬렉션), 남은 `members` 문서, Storage의 `videos/{groupId}/` 파일을 정리합니다.
5. **API 키 제한 권장**: Google Cloud Console > API 및 서비스 > 사용자 인증 정보에서 iOS API 키를 **iOS 앱 제한(번들 ID `com.hyeon.SetLogPlus`)** 으로 제한하고, 필요한 API만 허용하도록 설정하세요.

> 참고: 초대 코드 조회(`where inviteCode == ...`)를 위해 로그인한 사용자는 모든 그룹 문서를 읽을 수 있습니다. 더 엄격하게 하려면 초대 코드 조회를 Callable Function으로 옮기는 것을 고려하세요.
