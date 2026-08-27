#!/bin/bash
# SideNote 가 열리지 않을 때 원인을 알아보는 스크립트.
# 읽기만 하고 아무것도 바꾸지 않는다. 결과를 그대로 전해 주면 된다.

echo "════ SideNote 진단 ════"

echo "── 이 맥 ──"
echo "  macOS   $(sw_vers -productVersion)"
echo "  칩      $(uname -m)"
if [ "$(sw_vers -productVersion | cut -d. -f1)" -lt 13 ] 2>/dev/null; then
  echo "  ⚠️ SideNote 는 macOS 13 이상이 필요합니다. 이게 원인입니다."
fi

echo "── 앱 위치 ──"
FOUND=""
for P in /Applications/SideNote.app "$HOME/Applications/SideNote.app"; do
  if [ -d "$P" ]; then echo "  ✓ $P"; FOUND="$P"; fi
done
for P in "$HOME/Downloads/SideNote.app" "$HOME/Desktop/SideNote.app"; do
  [ -d "$P" ] && echo "  ⚠️ $P  ← 응용 프로그램 폴더로 옮겨야 합니다"
done
if [ -z "$FOUND" ]; then
  echo "  ✗ 응용 프로그램 폴더에 없습니다. dmg 안의 앱을 끌어다 놓으셨는지 확인해 주세요."
  echo "════ 끝 ════"
  exit 0
fi

echo "── 앱 정보 ──"
echo "  버전    $(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$FOUND/Contents/Info.plist" 2>/dev/null)"
echo "  요구    macOS $(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$FOUND/Contents/Info.plist" 2>/dev/null) 이상"
echo "  실행파일 $([ -x "$FOUND/Contents/MacOS/SideNote" ] && echo '있음' || echo '없음 ✗')"
echo "  아키텍처 $(lipo -info "$FOUND/Contents/MacOS/SideNote" 2>/dev/null | sed 's/.*are: //;s/.*file: //')"

echo "── 실행 여부 ──"
if pgrep -x SideNote >/dev/null; then
  echo "  ✓ 지금 실행 중입니다 (PID $(pgrep -x SideNote))"
  echo "    이 앱은 Dock 에 아이콘이 없습니다. 메뉴바 오른쪽 위의 체크리스트 아이콘,"
  echo "    또는 화면 오른쪽 끝의 얇은 색 선 4개를 찾아보세요."
else
  echo "  ✗ 실행 중이 아닙니다"
fi

echo "── 격리 표시 ──"
if xattr -p com.apple.quarantine "$FOUND" >/dev/null 2>&1; then
  echo "  ⚠️ 아직 격리돼 있습니다 (시스템 설정에서 '그래도 열기' 를 아직 안 누르셨을 수 있습니다)"
else
  echo "  없음 (정상)"
fi

echo "── 서명 ──"
codesign -v "$FOUND" 2>&1 | head -3 | sed 's/^/  /'
codesign -v "$FOUND" >/dev/null 2>&1 && echo "  정상"

echo "── 최근 크래시 기록 ──"
CRASH=$(ls -t ~/Library/Logs/DiagnosticReports/ 2>/dev/null | grep -i sidenote | head -1)
if [ -n "$CRASH" ]; then
  echo "  $CRASH"
  grep -m1 -E '"exception"|Exception Type|termination' ~/Library/Logs/DiagnosticReports/"$CRASH" 2>/dev/null | sed 's/^/    /'
else
  echo "  없음"
fi

echo "── 직접 실행해 보기 ──"
if pgrep -x SideNote >/dev/null; then
  echo "  이미 실행 중이라 건너뜁니다 (돌고 있는 앱을 끄지 않기 위해)"
else
  LOG=$(mktemp)
  "$FOUND/Contents/MacOS/SideNote" >"$LOG" 2>&1 &
  APPPID=$!
  sleep 6
  # 이 스크립트가 띄운 것만 정확히 끈다. 다른 인스턴스는 건드리지 않는다.
  kill "$APPPID" 2>/dev/null
  wait "$APPPID" 2>/dev/null
  if [ -s "$LOG" ]; then head -20 "$LOG" | sed 's/^/  /'
  else echo "  오류 없이 실행됐습니다 (그렇다면 앱은 정상이고, 메뉴바를 못 찾으신 것일 수 있습니다)"; fi
  rm -f "$LOG"
fi

echo "════ 끝 ════"
