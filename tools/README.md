# tools

## pills.sqlite 생성
```bash
export DATA_GO_KR_KEY=<공공데이터포털 인증키>   # 커밋 금지
python3 tools/build_db.py --save-json tools/cache/all.json
# 이후 재생성: python3 tools/build_db.py --from-json tools/cache/all.json
```
산출물은 `MediLens/Data/Resources/pills.sqlite` (gitignore됨, 앱 번들에 포함).
`ImprintNormalizer`(Swift)와 `norm_imprint`(Python)의 정규화 규칙은 항상 같아야 한다.
