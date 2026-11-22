extends GutTest


func test_basic_arithmetic_and_floor_division() -> void:
	assert_eq(Formula.int_value("2*P", {"P": 3}), 6)
	assert_eq(Formula.int_value("(v + 1) // 2", {"v": 4}), 2)
	assert_eq(Formula.int_value("v // 4", {"v": 6}), 1)


func test_functions_min_max_ceil() -> void:
	assert_eq(Formula.int_value("min(5, L // 10 + 1)", {"L": 47}), 5)
	assert_eq(Formula.int_value("min(5, L // 10 + 1)", {"L": 9}), 1)
	assert_eq(Formula.int_value("ceil(P/2)", {"P": 5}), 3)
	assert_eq(Formula.int_value("max(0, t - 3)", {"t": 4}), 1)
	assert_eq(Formula.int_value("max(0, t - 3)", {"t": 2}), 0)


func test_numbers_pass_through() -> void:
	assert_eq(Formula.int_value(7), 7)
	assert_almost_eq(Formula.value("0.5 * 3"), 1.5, 0.0001)


func test_unary_minus() -> void:
	assert_eq(Formula.int_value("-2 + 5"), 3)
