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

## DB 스키마 (초안)
```sql
CREATE TABLE pill (
  item_seq      TEXT PRIMARY KEY,   -- 품목일련번호
  name          TEXT NOT NULL,
  company       TEXT,
  shape         TEXT,               -- 의약품 모양
  color_front   TEXT,
  color_back    TEXT,
  form          TEXT,               -- 제형 (정제/캡슐 등)
  line_front    TEXT,               -- 분할선
  line_back     TEXT,
  imprint_front TEXT,
  imprint_back  TEXT,
  length_mm REAL, width_mm REAL, thick_mm REAL,
  image_url     TEXT,
  class_name    TEXT,               -- 분류명
  etc_otc       TEXT                -- 전문/일반
);
CREATE INDEX idx_pill_shape_color ON pill(shape, color_front);
CREATE VIRTUAL TABLE pill_imprint_fts USING fts5(
  imprint_front, imprint_back, content='pill', content_rowid='rowid'
);
```
컬럼명은 공공데이터 실제 필드 확인 후 확정한다.

## 개발 단계
1. **데이터**: `tools/build_db.py`로 pills.sqlite 생성
2. **1단계 – 속성 검색**: 모양/색/각인 직접 입력 → 후보 목록 → 상세
3. **2단계 – 사진 분석**: 촬영 → 색/모양/각인 자동 추출 → 사용자 확인/수정 → 1단계 검색 재사용
4. **3단계 – 정확도 개선**: 각인 전처리(대비 강조, 크롭), 부분 일치 랭킹, 필요 시 소형 Core ML

## 결정 사항 / 미결정
- 확정: SwiftUI, GRDB, XcodeGen, 서버 없음
- 미결정: 최소 iOS 버전(17 가정), 사용자 데이터(SwiftData) 도입 시점, 공공데이터 수령 방식(API vs CSV)
