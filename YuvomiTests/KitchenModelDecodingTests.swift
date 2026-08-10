import XCTest
@testable import Yuvomi

final class KitchenModelDecodingTests: XCTestCase {
    func testMealWeekDecoding() throws {
        let json = """
        {"data":[{"id":1,"date":"2026-08-11","meal_type":"dinner","title":"Pasta night","notes":null,"recipe_id":null,"ingredients":[],"recipe_ingredient_count":0}],"weekStart":"2026-08-10","weekEnd":"2026-08-16"}
        """.data(using: .utf8)!
        let week = try JSONDecoder().decode(MealsWeekResponse.self, from: json)
        XCTAssertEqual(week.data.count, 1)
        XCTAssertEqual(week.data[0].mealType, "dinner")
        XCTAssertEqual(week.weekStart, "2026-08-10")
    }

    func testRecipeIngredients() throws {
        let json = """
        {"id":1,"title":"Pancakes","notes":"Yum","recipe_url":null,"meal_types":["breakfast"],"ingredients":[{"id":1,"name":"Flour","quantity":"2","category":"Other"}],"source":"native","creator_name":"A"}
        """.data(using: .utf8)!
        let recipe = try JSONDecoder().decode(Recipe.self, from: json)
        XCTAssertEqual(recipe.ingredients.count, 1)
        XCTAssertEqual(recipe.ingredients[0].name, "Flour")
    }

    func testPantryQuantityDouble() throws {
        let json = """
        {"id":1,"name":"Milk","quantity":0.5,"unit":"L","location_id":2,"location_name":"Fridge","category":"Dairy","expires_on":null,"min_quantity":1,"notes":null}
        """.data(using: .utf8)!
        let item = try JSONDecoder().decode(PantryItem.self, from: json)
        XCTAssertEqual(item.quantity, 0.5, accuracy: 0.001)
        XCTAssertTrue(item.isLow)
    }
}
