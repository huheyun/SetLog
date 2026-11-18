# SETLOG+

친구들과 그룹을 만들어 **매시간 3초짜리 영상**으로 하루를 기록하고 공유하는 iOS 앱입니다.
가볍게 찍고, 그룹 피드에서 서로의 순간을 보고, 반응·댓글·채팅으로 이야기합니다.

- UIKit (코드 기반 레이아웃), iOS 26+, Swift 5 모드 (기본 MainActor 격리)
- Firebase Authentication · Cloud Firestore · Cloud Storage · Cloud Functions

## 주요 기능

### 기록
- **3초 영상 촬영**: 전면/후면 전환, 0.5×~2× 줌, 플래시, 촬영 진행 링
- **셀프 타이머**: 끔 → 3초 → 10초. 카운트다운 중 촬영 버튼을 다시 누르면 취소
- **여러 그룹에 한 번에 업로드**: 소리 포함 여부 선택, 실패한 그룹만 다시 시도
- **매시간 촬영 알림**: 프로필에서 켜고 시간대(예: 9시~22시)를 설정. 서버 없이 로컬 알림으로 동작하고, 알림을 누르면 카메라가 열림

### 보기
- **그룹 피드**: 시간대 칩으로 이동, 멤버별 영상 카드, 아직 올리지 않은 멤버 표시
- **지난 기록 보기**: 날짜 이동 버튼과 달력(기록이 있는 날 표시)으로 과거 날짜 탐색
- **영상 상세**: 전체 화면 반복 재생, 탭하면 일시정지/재생, 아래로 쓸어내려 닫기
- **하루 영상 만들기**: 그날의 3초 영상들을 시간순으로 이어 붙인 영상을 만들어 사진 앱에 저장하거나 공유 (실기기에서는 각 클립에 작성자·시간 자막 표시)
- **영상 캐시**: 한 번 받은 영상은 기기에 저장해 바로 재생 (7일 후 자동 정리)

### 소통
- **이모지 반응**: 버튼 옆에 뜨는 작은 이모지 바. 같은 이모지를 다시 누르면 취소
- **댓글**: 영상 상세에서 댓글 시트. 내 댓글과 내 게시물의 댓글은 삭제 가능
- **그룹 채팅**: 그룹별 실시간 채팅
- **내 게시물 관리**: 내 영상 삭제, 이번 시간 영상 다시 찍기

### 그룹과 계정
- 이메일 회원가입/로그인, 닉네임 변경, 로그아웃
- 그룹 만들기, 초대 코드로 참여(복사·공유), 그룹 나가기, 그룹장의 그룹 삭제

## 프로젝트 구조

| 폴더 | 내용 |
| --- | --- |
| `App/` | 화면 전환(`AppRouter`) |
| `Auth/` | 로그인, 회원가입 |
| `Feed/` | 홈(그룹 목록), 그룹 피드, 날짜 선택, 그룹 설정 |
| `Upload/` | 카메라 촬영, 업로드할 그룹 선택 |
| `VideoDetail/` | 영상 상세, 댓글 |
| `DayRecap/` | 하루 영상 만들기 |
| `Chat/` | 그룹 채팅 |
| `Profile/` | 프로필, 알림 설정 |
| `Services/` | Firebase 저장소 계층, 영상 업로드·캐시·음소거, 알림 예약 |
| `Models/` | 사용자, 그룹, 멤버, 게시물, 반응, 댓글 모델 |
| `Shared/` | 디자인 시스템(`AppTheme`), 공통 버튼·카드·토스트, 시간 유틸, 영상 미리보기 |

## 실행 방법

1. Firebase 콘솔 > 프로젝트 설정 > iOS 앱에서 `GoogleService-Info.plist`를 내려받아 `SetLogPlus/` 폴더에 넣습니다. 이 파일은 `.gitignore`에 포함되어 커밋되지 않습니다.
2. `SetLogPlus.xcodeproj`를 Xcode로 열고 실행합니다(⌘R).
   - 시뮬레이터에는 카메라가 없어 촬영은 실기기에서 확인해야 합니다.
   - 실기기 실행 시 Signing & Capabilities에서 Team을 선택하고, 기기에서 개발자 모드를 켜야 합니다.

## Firebase 데이터 구조

| 경로 | 내용 |
| --- | --- |
| `users/{uid}` | 프로필 (이메일, 닉네임) |
| `groups/{groupID}` | 그룹 (이름, 그룹장, 멤버 ID 목록, 초대 코드) |
| `groups/{groupID}/members/{uid}` | 그룹 멤버 (닉네임, 역할) |
| `groups/{groupID}/messages/{messageID}` | 그룹 채팅 메시지 |
| `posts/{postID}` | 3초 영상 게시물 (그룹, 작성자, 시간대 `yyyyMMddHH`, 영상 URL) |
| `posts/{postID}/reactions/{uid}` | 이모지 반응 (사용자당 1개) |
| `posts/{postID}/comments/{commentID}` | 댓글 |
| Storage `videos/{groupID}/{uid}/{fileName}.mov` | 영상 파일 |

## Firebase 서버 설정

서버 설정 파일은 저장소 루트에 있습니다: `firebase.json`, `.firebaserc`(기본 프로젝트 `setlogplus`), `firestore.rules`, `storage.rules`, `firestore.indexes.json`, `functions/`.

1. **보안 규칙 배포** (무료 요금제에서도 가능):
   ```bash
   npx firebase-tools login
   npx firebase-tools deploy --only firestore:rules,storage
   ```
   - `storage.rules`는 그룹 멤버 확인을 위해 Firestore를 교차 조회합니다. 첫 배포 때 권한 부여 안내가 나오면 승인해야 영상 업로드와 재생이 동작합니다.
2. **Cloud Functions 배포** (**Blaze 요금제 필요**):
   ```bash
   cd functions && npm install && cd ..
   npx firebase-tools deploy --only functions
   ```
   - `onGroupDeleted`: 그룹이 삭제되면 그 그룹의 게시물(반응·댓글 포함), 멤버, 채팅 메시지, Storage 영상을 정리합니다.
   - `onPostDeleted`: 게시물이 삭제되면 반응·댓글 하위 컬렉션과 Storage 영상 파일을 정리합니다.
3. **API 키 제한 권장**: Google Cloud Console > API 및 서비스 > 사용자 인증 정보에서 iOS API 키를 iOS 앱(번들 ID `com.hyeon.SetLogPlus`)으로 제한하세요.

> 참고: 초대 코드 조회(`where inviteCode == ...`)를 위해 로그인한 사용자는 모든 그룹 문서를 읽을 수 있습니다. 더 엄격하게 하려면 초대 코드 조회를 Callable Function으로 옮기세요.

## 테스트 체크리스트

- 회원가입/로그인, 닉네임 변경, 로그아웃
- 그룹 만들기, 초대 코드 복사·공유·참여, 나가기, 삭제
- 3초 촬영(타이머 3초/10초 포함), 여러 그룹 업로드
- 그룹 피드 시간대·날짜 이동, 달력에서 과거 날짜 선택
- 영상 상세: 반복 재생, 일시정지, 소리, 반응, 댓글, 내 영상 삭제/다시 찍기
- 하루 영상 만들기 → 사진 앱 저장, 공유
- 그룹 채팅 보내기/받기
- 매시간 알림 켜기 → 알림 탭 시 카메라 열림
