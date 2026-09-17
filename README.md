# TrueDepthTrigger

TrueDepth 거리 측정 + BLE True 전송 iOS App Playground (`.swiftpm`).

검출 범위 하한/상한 슬라이더는 서로 독립으로 움직이고, 하한이 상한을 넘을 수 없습니다.

## 열는 방법

1. GitHub 오른쪽 **Code → Download ZIP**
2. 압축 풀기
3. 폴더 이름을 `TrueDepthTrigger.swiftpm` 으로 바꾸기
4. Xcode 또는 Swift Playgrounds에서 그 폴더 열기
5. Face ID iPhone에서 실행 (TrueDepth 필요)

클론한 경우:

```bash
git clone https://github.com/ksh900222/TrueDepthTrigger.git
mv TrueDepthTrigger TrueDepthTrigger.swiftpm
open TrueDepthTrigger.swiftpm
```

카메라/블루투스 권한은 `Package.swift`에 들어 있습니다.
