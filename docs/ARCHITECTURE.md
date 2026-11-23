# MediLens 프로젝트 구조 설계

서버 없이 동작하는 iOS 앱. 식약처 낱알식별 데이터를 SQLite로 내장하고, 사진에서 추출한 속성(모양/색/각인)으로 후보를 검색한다.

## 기술 스택
- Swift 5.9+, SwiftUI (iOS 17+)
- Vision / Core Image (사진 분석)
- SQLite + GRDB.swift (내장 읽기 전용 DB, FTS5)
- SwiftData (선택, 즐겨찾기/검색 기록)
- XcodeGen (`project.yml` → `.xcodeproj` 생성, 프로젝트 파일 충돌 방지)

## 디렉터리 구조
```
MediLens/
├─ project.yml                  # XcodeGen 설정
├─ docs/
│  └─ ARCHITECTURE.md
├─ tools/                       # 오프라인 데이터 준비 (개발 PC에서 1회 실행)
│  ├─ build_db.py               # 공공데이터 CSV/API → pills.sqlite
│  ├─ requirements.txt
│  └─ README.md
├─ MediLens/                    # 앱 타깃
│  ├─ App/
│  │  ├─ MediLensApp.swift      # 진입점, DI 구성
│  │  └─ AppContainer.swift     # 의존성 조립
│  ├─ Domain/                   # 순수 Swift (UI/프레임워크 비의존)
│  │  ├─ Models/
│  │  │  ├─ Pill.swift          # 의약품 엔티티
│  │  │  ├─ PillQuery.swift     # 검색 조건 (모양/색/각인/분할선/제형)
│  │  │  ├─ PillShape.swift     # enum, 식약처 분류와 매핑
│  │  │  └─ PillColor.swift
│  │  └─ UseCases/
│  │     ├─ SearchPillsUseCase.swift
│  │     └─ AnalyzePillImageUseCase.swift
│  ├─ Data/
│  │  ├─ Database/
│  │  │  ├─ PillDatabase.swift  # GRDB 연결, 번들 DB 읽기 전용 오픈
│  │  │  ├─ PillRecord.swift    # DB 레코드 ↔ Domain 변환
│  │  │  └─ PillRepository.swift
│  │  └─ Resources/
│  │     └─ pills.sqlite        # tools/build_db.py 산출물 (번들)
│  ├─ Vision/                   # 사진 분석 (2단계)
│  │  ├─ PillSegmenter.swift    # 알약 영역 분리
│  │  ├─ ColorClassifier.swift
│  │  ├─ ShapeClassifier.swift
│  │  └─ ImprintRecognizer.swift  # VNRecognizeTextRequest + 전처리
│  ├─ Features/                 # SwiftUI 화면 + ViewModel
│  │  ├─ Search/                # 속성 필터 검색 (1단계)
│  │  ├─ Camera/                # 촬영 (2단계)
│  │  ├─ Result/                # 후보 목록, 확인/수정
│  │  └─ Detail/                # 의약품 상세
│  ├─ Shared/                   # 공통 UI 컴포넌트, 확장
│  └─ Assets.xcassets
├─ MediLensTests/
│  ├─ Domain/
│  ├─ Data/                     # 인메모리/샘플 DB로 검색 테스트
│  └─ Vision/                   # 샘플 이미지 기반 테스트
└─ README.md
```

## 계층과 의존 방향
```
Features (SwiftUI + ViewModel)
   ↓
Domain (UseCases, Models)  ← 프로토콜로 Data/Vision을 추상화
   ↑
Data (GRDB)   Vision (Vision/CoreImage)
```
- Domain은 SwiftUI, GRDB, Vision을 import하지 않는다 → 단위 테스트가 쉽고 UI/DB 교체 가능.
- Data/Vision이 Domain의 프로토콜(`PillRepositoryProtocol`, `PillImageAnalyzing`)을 구현.

## 데이터 소스: 식약처 의약품 낱알식별 정보 API (실측 결과)
- 엔드포인트: `https://apis.data.go.kr/1471000/MdcinGrnIdntfcInfoService03/getMdcinGrnIdntfcInfoList03`
- 파라미터: `serviceKey`, `pageNo`, `numOfRows`(**최대 500**), `type=json`
- 전체 25,517건(ITEM_SEQ 중복 17건 → upsert 필수), 500건씩 52회 호출로 전체 수집 가능
- 이미지: 전부 `https://nedrug.mfds.go.kr/...` (HTTPS, ATS 설정 불필요)
- **API 키는 레포에 커밋하지 않는다** (환경 변수 `DATA_GO_KR_KEY` 또는 gitignore된 설정 파일)

### 필드 특성 (DB 설계에 반영)
| 필드 | 특성 |
|---|---|
| DRUG_SHAPE | 원형, 타원형, 장방형, 기타, 팔각형, 사각형, 삼각형, 마름모형, 육각형, 오각형, 반원형 (11종) |
| COLOR_CLASS1/2 | 하양, 분홍, 노랑 등. **"노랑, 투명"처럼 복합 값 존재**, CLASS2는 약 16%만 값 있음 |
| PRINT_FRONT/BACK | 각인. 앞면 99%, 뒷면 49%. **"분할선", "마크" 같은 토큰이 섞임** (예: `J분할선W`) → 정규화 필요 |
| LINE_FRONT/BACK | `-`, `+`, `기타`, null |
| MARK_CODE_* | 마크 이미지 정보(약 9%), 보조용 |
| LENG_LONG/SHORT/THICK | 문자열 mm. 일부 null |
| FORM_CODE_NAME | 필름코팅정, 나정, 경질캡슐제 등 |
| IMG_REGIST_TS | 이미지 등록일 (YYYYMMDD), 전 건 존재, 최신 2026-11-19 |
| CHANGE_DATE | 변경일, 약 8% null |

### 증분 동기화 제약 (실측)
- 날짜 조건은 **`img_regist_ts`만 동작하며 "해당 일자 정확 일치"** 이다. 범위(이상/이하) 조회 불가.
- `change_date`, `item_permit_date` 등 다른 날짜 파라미터는 **무시되고 전체가 반환**된다.
- 따라서 `last_synced_date` 다음 날부터 오늘까지 **하루씩 반복 호출**한다. (하루 데이터는 대체로 1~10건 수준)
- 기존 품목의 변경(CHANGE_DATE)은 이 방식으로 감지되지 않는다 → 앱 버전 업데이트 시 번들 DB를 재생성하거나, 주기적 전체 재수집(52회)을 별도로 둔다.
- 앱 실행 시 백그라운드로 실행, 실패해도 기존 DB로 정상 동작. 호출 한도/키 노출 위험은 감수하되 추후 프록시로 교체 가능하게 `RemoteSyncClient` 프로토콜로 분리.

## 카메라/비전 파이프라인 (주 기능: 한 번 찍으면 사진 속 약을 모두 찾는다)
생김새 검색(모양/색/각인 수동 선택)은 보조 기능이며, 사진 인식 결과를 **수정/보완하는 용도**로도 재사용한다.

```
촬영(AVFoundation) 또는 앨범
  → ① 약 분리: VNGenerateForegroundInstanceMaskRequest (iOS 17, 인스턴스별 마스크) + 밀착 시 분리 보정
  → ② 알약별 크롭/회전 정규화 (마스크의 주축 기준)
  → ③ 속성 추출 (알약마다 독립 실행, 병렬)
       · 색: 배경으로 화이트밸런스 보정 → Lab 색공간 → 식약처 색 분류로 매핑 (투톤은 장축 양쪽을 따로)
       · 모양: 윤곽 다각형 근사 + 종횡비/원형도 → 모양 확률 분포
       · 각인: VNRecognizeTextRequest + 대비 강화, 4방향 회전 시도 (읽은 후보와 확신도 목록)
       · (선택) 동전 등 기준물로 mm 보정 → 크기
  → ④ PillMatcher: 후보 조회(모양/색 허용 범위) 후 점수화 — Domain/Recognition (구현됨, 순수 로직)
  → ⑤ 알약별 상위 후보 + 사진 비교 → 사용자가 확인/수정 (오인식 대비)
```
- **확률적 매칭**: 사진 속성은 틀릴 수 있으므로 "일치=가점, 불일치=감점"이며 즉시 탈락시키지 않는다. 자주 혼동되는 모양/색 쌍은 부분 점수(`shapeAffinity`, `colorAffinity`)를 준다.
- **각인**이 가장 변별력이 높지만 음각/양각이라 OCR이 가장 불안정하다 → 읽히면 강하게 반영, 못 읽어도 불이익 없음.
- **기대 정확도**: 1순위 단정이 아니라 "상위 후보 + 확인" UX를 전제로 한다. 정확도는 실제 사진으로 측정/튜닝이 필요하다.
- **촬영 가이드**: 무늬 없는 단색 배경, 약끼리 간격 두기, 위에서 수직 촬영 (분리/색/각인 정확도에 직접 영향).
- **동률 후보 처리**: 실제 DB로 매처를 시뮬레이션해 보니 각인이 없으면(예: 하양·파랑 장방형 캡슐) 점수가 같은 후보가 수백 개다. 상위 후보 점수가 거의 같으면 "아주 비슷해요" 대신 "후보 중 하나예요"로 표시하고 각인 입력을 유도한다 (`ScannedPill.isAmbiguous`).
- **검증 한계**: 약 참고 사진 서버(nedrug.mfds.go.kr)는 클라우드 환경에서 TLS가 차단되어 개발 환경에서 알고리즘 튜닝을 못 했다.
  Mac에서는 접근 가능하므로 `tools/`의 벤치마크로 색/모양 매핑을 보정한다. 실사진 샘플이 확보되면 먼저 이를 기준으로 분리/속성 추출을 검증한다.

## UI/UX 설계 원칙 (토스의 모바일 UX 원칙을 참고)
- **한 화면에 질문 하나**: 모양 → 색 → 각인 → 결과의 단계형 흐름. 상단 진행 바, 단계 이동 시 좌우 슬라이드.
- **즉각적인 피드백**: 조건을 바꿀 때마다 "조건에 맞는 약 N개"가 숫자 애니메이션으로 갱신된다 (FTS/인덱스 덕에 실시간).
- **하단 고정 CTA**: 주 행동은 항상 화면 하단 큰 버튼 하나, 보조 행동("잘 모르겠어요")은 텍스트 버튼.
- **큰 타이포 + 넉넉한 여백 + 연회색 배경 위 흰 카드**, 눌림 반응(스케일), 선택 시 햅틱.
- **모르면 건너뛰기**: 모든 조건은 선택 사항. 결과 화면의 조건 칩으로 언제든 수정.
- **디자인 토큰화**: `Shared/DesignSystem` (Palette/Metrics/Components). 다크 모드 자동 대응. 폰트는 시스템 폰트(Dynamic Type 대응).
- 의료 앱이므로 홈/상세에 "참고용, 복용 전 의사·약사 확인" 문구를 항상 노출.
- 토스의 폰트/아이콘 등 고유 자산은 사용하지 않고 원칙만 참고한다.

## 증분 동기화 설계 (구현: `Domain/Sync`, `Data/Remote`, `Data/Sync`)
앱 실행 직후 백그라운드에서 실행하며, UI는 내장 DB로 즉시 사용 가능하다.

| 최적화 | 내용 | 근거(실측) |
|---|---|---|
| 병렬 + 동시성 상한 | 슬라이딩 윈도우로 최대 8개 동시 요청 (`forEachConcurrent`) | 40건 기준 순차 약 3.9초/건 → 8병렬 16.9초 |
| 전략 전환 | 공백 ≤ 90일: 일자별 조회, 초과: 500건 단위 전체 페이지 병렬 수집 | 일자 조회는 응답이 작고(1~10건), 장기 공백은 요청 수가 더 적은 쪽이 유리 |
| 연결 재사용 | `httpMaximumConnectionsPerHost`를 동시성 상한과 일치 | HTTP keep-alive/멀티플렉싱 |
| 재시도 | 연결 끊김/5xx/429 지수 백오프(최대 3회), 403은 즉시 중단 | 연결 reset이 간헐적으로 발생 |
| 정확성 | 마지막 동기화일은 **앞에서부터 연속 성공한 날까지만** 전진, 3일 겹침 재조회(upsert 멱등) | 실패한 날/늦게 반영된 등록 건 누락 방지 |
| DB 쓰기 | 응답 단위 1 트랜잭션, 준비된 구문 재사용, `ON CONFLICT DO UPDATE`로 rowid 유지 + FTS 'delete' 후 재삽입 | 25.5k건 upsert 0.26초, FTS 무결성 검증 완료 |
| 읽기 비차단 | `DatabasePool`(WAL) — 동기화 쓰기 중에도 검색 가능 | |
| 과호출 방지 | 마지막 성공 후 1시간 내에는 건너뜀 | 키 호출 한도 보호 |
| 번들 교체 | 앱 업데이트로 더 최신 `bundle_date` DB가 들어오면 복사본 교체 | 오래된 설치본 DB가 남는 문제 방지 |

API 키는 `Config/Secrets.xcconfig`(gitignore) → Info.plist `DataGoKrKey`로 주입한다. 키가 없으면 동기화만 비활성화된다.
결과 0건인 날은 응답에 `items` 키가 없으므로 디코딩은 옵셔널로 처리한다.

## DB 스키마 (실제 필드 기반)
```sql
CREATE TABLE pill (
  item_seq        TEXT PRIMARY KEY,
  name            TEXT NOT NULL,
  eng_name        TEXT,
  company         TEXT,
  chart           TEXT,             -- 성상 설명문
  shape           TEXT,             -- DRUG_SHAPE
  color1          TEXT,             -- 원본 보존
  color2          TEXT,
  form            TEXT,             -- FORM_CODE_NAME
  print_front     TEXT,             -- 원본
  print_back      TEXT,
  imprint_front_norm TEXT,          -- 정규화(분할선/마크 토큰 제거, 대문자)
  imprint_back_norm  TEXT,
  line_front      TEXT,
  line_back       TEXT,
  len_long REAL, len_short REAL, thick REAL,
  image_url       TEXT,
  img_regist_ts   TEXT,             -- YYYYMMDD, 증분 동기화 기준
  change_date     TEXT,
  class_name      TEXT,
  etc_otc         TEXT,
  ambiguous       INTEGER DEFAULT 0 -- 사진 교차검증 결과 모호 플래그(선택)
);
CREATE TABLE pill_color (item_seq TEXT, color TEXT);  -- 복합 색을 분해 ("노랑, 투명" → 노랑, 투명)
CREATE INDEX idx_pill_shape ON pill(shape);
CREATE INDEX idx_pill_color ON pill_color(color, item_seq);
CREATE VIRTUAL TABLE pill_imprint_fts USING fts5(
  imprint_front_norm, imprint_back_norm, content='pill', content_rowid='rowid'
);
CREATE TABLE sync_meta (key TEXT PRIMARY KEY, value TEXT); -- last_synced_date 등
```

## 사진 활용 방침
- 후보 목록에 **참고 사진을 표시**한다 (원격 URL + 디스크 캐시, 오프라인이면 텍스트만).
- 사진 비전 분석(색/모양/각인 OCR)은 **DB 적재 단계(tools/)에서 1회** 수행해 컬럼으로 저장하고, API 분류와 불일치하면 `ambiguous` 플래그로 검색 시 둘 다 허용한다. 앱 내 증분 업데이트에서는 사진 분석을 하지 않는다.
- 이미지 유사도(feature print)는 1순위 매칭이 아니라 후보 재정렬 보조로만 검토한다.

## 개발 단계
1. **데이터**: `tools/build_db.py`로 pills.sqlite 생성
2. **1단계 – 속성 검색**: 모양/색/각인 직접 입력 → 후보 목록 → 상세
3. **2단계 – 사진 분석**: 촬영 → 색/모양/각인 자동 추출 → 사용자 확인/수정 → 1단계 검색 재사용
4. **3단계 – 정확도 개선**: 각인 전처리(대비 강조, 크롭), 부분 일치 랭킹, 필요 시 소형 Core ML

## 결정 사항 / 미결정
- 확정: SwiftUI, GRDB, XcodeGen, 서버 없음
- 확정: 데이터는 공공데이터포털 API(전체 수집 + 일자별 증분)
- 미결정: 최소 iOS 버전(17 가정), 사용자 데이터(SwiftData) 도입 시점
