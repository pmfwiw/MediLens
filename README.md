# MediLens
MediLens: 알약 사진 한 장으로 의약품을 식별합니다. 식약처 낱알식별 정보(공공데이터포털)를 앱에 내장해 서버 없이 동작하는 것을 목표로 합니다.

## 시작하기 (Mac)
```bash
brew install xcodegen
export DATA_GO_KR_KEY=...                        # 공공데이터포털 키 (커밋 금지)
python3 tools/build_db.py --save-json tools/cache/all.json
xcodegen generate && open MediLens.xcodeproj
```
설계는 [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md), 데이터 준비는 [tools/README.md](tools/README.md) 참고.
