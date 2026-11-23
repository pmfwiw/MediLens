import Foundation

/// 동시 실행 수를 `limit`으로 제한하며 inputs를 처리한다. 결과는 완료되는 대로 onResult로 전달(순서 무관).
/// 슬라이딩 윈도우 방식이라 느린 요청 하나가 전체를 막지 않는다.
func forEachConcurrent<Input: Sendable, Output: Sendable>(
    _ inputs: [Input], limit: Int,
    work: @escaping @Sendable (Input) async -> Output,
    onResult: (Input, Output) -> Void
) async {
    await withTaskGroup(of: (Int, Output).self) { group in
        var next = 0
        while next < min(max(limit, 1), inputs.count) {
            let i = next; next += 1
            group.addTask { (i, await work(inputs[i])) }
        }
        while let (i, out) = await group.next() {
            onResult(inputs[i], out)
            if next < inputs.count {
                let j = next; next += 1
                group.addTask { (j, await work(inputs[j])) }
            }
        }
    }
}
