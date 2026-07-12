import XCTest
@testable import FatLossTracker

final class FatLossTrackerTests: XCTestCase {
    func testFoodDraftDecodesAIResponseWithoutID() throws {
        let json = #"{"name":"米饭","amount":"200g","calories":232,"protein":5.2,"fat":0.6,"carbs":51.6}"#
        let food = try JSONDecoder().decode(FoodDraft.self, from: Data(json.utf8))

        XCTAssertEqual(food.name, "米饭")
        XCTAssertEqual(food.calories, 232)
    }

    func testExtractFoodsAcceptsMarkdownJSON() {
        let response = """
        ```json
        {"foods":[{"name":"鸡蛋","amount":"2个","calories":140,"protein":12,"fat":10,"carbs":2}]}
        ```
        """

        let foods = AppState.extractFoods(from: response)
        XCTAssertEqual(foods?.count, 1)
        XCTAssertEqual(foods?.first?.name, "鸡蛋")
    }

    func testCSVFieldEscapesCommaQuoteAndNewline() {
        XCTAssertEqual(AppState.csvField("普通备注"), "普通备注")
        XCTAssertEqual(AppState.csvField("少油,少盐"), "\"少油,少盐\"")
        XCTAssertEqual(AppState.csvField("他说\"少油\""), "\"他说\"\"少油\"\"\"")
        XCTAssertEqual(AppState.csvField("第一行\n第二行"), "\"第一行\n第二行\"")
    }

    func testBMIUsesHeightInCentimeters() {
        let info = PersonalInfo(height: 180, bodyFatPercentage: 20)
        XCTAssertEqual(info.bmi(weight: 81), 25, accuracy: 0.001)
    }

    func testAIEndpointRequiresHTTPSExceptForLocalhost() {
        XCTAssertEqual(
            AppState.aiEndpointURL(from: "https://api.openai.com/v1")?.absoluteString,
            "https://api.openai.com/v1/chat/completions"
        )
        XCTAssertNil(AppState.aiEndpointURL(from: "http://example.com/v1"))
        XCTAssertNotNil(AppState.aiEndpointURL(from: "http://localhost:11434/v1"))
    }
}
