"""Koffee ETL submodule: mock_data."""

from typing import Any

# =============================================================================
# MOCK DATA (For Demonstration)
# =============================================================================


def get_mock_nutrition_data() -> list[dict[str, Any]]:
    """
    Generate mock USDA-style nutrition data for demonstration.
    """
    return [
        # High fiber items (Fiber Firewall activated)
        {
            "external_db_id": "USDA-171688",
            "name": "Chia Seeds",
            "category": "Seeds",
            "calories": 486,
            "protein_g": 16.5,
            "carbs_g": 42.1,
            "fat_g": 30.8,
            "fiber_g": 34.4,  # > 5.0, triggers absorption blocker
            "requires_fasted_state": 0,
        },
        {
            "external_db_id": "USDA-168894",
            "name": "Psyllium Husk",
            "category": "Fiber Supplement",
            "calories": 20,
            "protein_g": 0,
            "carbs_g": 4,
            "fat_g": 0,
            "fiber_g": 5.5,  # > 5.0, triggers absorption blocker
            "requires_fasted_state": 1,
        },
        {
            "external_db_id": "USDA-169917",
            "name": "Lentils, cooked",
            "category": "Legumes",
            "calories": 116,
            "protein_g": 9.0,
            "carbs_g": 20.0,
            "fat_g": 0.4,
            "fiber_g": 7.9,  # > 5.0, triggers absorption blocker
            "requires_fasted_state": 0,
        },
        # High protein items (Amino Acid Carrier Effect)
        {
            "external_db_id": "USDA-171477",
            "name": "Chicken Breast, grilled",
            "category": "Protein",
            "calories": 165,
            "protein_g": 31.0,  # > 20g, overrides fasted state
            "carbs_g": 0,
            "fat_g": 3.6,
            "fiber_g": 0,
            "requires_fasted_state": 0,
        },
        {
            "external_db_id": "USDA-175168",
            "name": "Salmon, Atlantic",
            "category": "Protein",
            "calories": 208,
            "protein_g": 20.0,  # Exactly 20g
            "carbs_g": 0,
            "fat_g": 13.0,
            "fiber_g": 0,
            "requires_fasted_state": 0,
        },
        {
            "external_db_id": "USDA-173944",
            "name": "Eggs, whole, scrambled",
            "category": "Protein",
            "calories": 149,
            "protein_g": 10.0,
            "carbs_g": 1.6,
            "fat_g": 11.0,
            "fiber_g": 0,
            "requires_fasted_state": 0,
        },
        # Standard items
        {
            "external_db_id": "USDA-173744",
            "name": "Oatmeal, cooked",
            "category": "Grains",
            "calories": 71,
            "protein_g": 2.5,
            "carbs_g": 12.0,
            "fat_g": 1.5,
            "fiber_g": 1.7,
            "requires_fasted_state": 0,
        },
        {
            "external_db_id": "USDA-171043",
            "name": "Brown Rice, cooked",
            "category": "Grains",
            "calories": 111,
            "protein_g": 2.6,
            "carbs_g": 23.0,
            "fat_g": 0.9,
            "fiber_g": 1.8,
            "requires_fasted_state": 0,
        },
        {
            "external_db_id": "USDA-173233",
            "name": "Greek Yogurt, plain",
            "category": "Dairy",
            "calories": 97,
            "protein_g": 9.0,
            "carbs_g": 3.6,
            "fat_g": 5.0,
            "fiber_g": 0,
            "requires_fasted_state": 0,
        },
        {
            "external_db_id": "USDA-171687",
            "name": "Almonds, raw",
            "category": "Nuts",
            "calories": 579,
            "protein_g": 21.2,
            "carbs_g": 21.6,
            "fat_g": 49.9,
            "fiber_g": 12.5,  # > 5.0, triggers absorption blocker
            "requires_fasted_state": 0,
        },
    ]


def get_mock_exercise_data() -> list[dict[str, Any]]:
    """
    Generate mock Wger-style exercise data for demonstration.
    """
    return [
        # HIIT (maintains_hepatic_perfusion = 0)
        {
            "external_db_id": "WGER-001",
            "name": "Sprint Intervals",
            "muscle_group": "Full Body",
            "base_met": 8.0,
            "intensity": "high",
        },
        {
            "external_db_id": "WGER-002",
            "name": "Burpees",
            "muscle_group": "Full Body",
            "base_met": 8.0,
            "intensity": "high",
        },
        {
            "external_db_id": "WGER-003",
            "name": "Jump Rope",
            "muscle_group": "Full Body",
            "base_met": 10.0,
            "intensity": "high",
        },
        # Zone 2 cardio (maintains_hepatic_perfusion = 1)
        {
            "external_db_id": "WGER-010",
            "name": "Light Jogging",
            "muscle_group": "Legs",
            "base_met": 6.0,
            "intensity": "moderate",
        },
        {
            "external_db_id": "WGER-011",
            "name": "Cycling, steady pace",
            "muscle_group": "Legs",
            "base_met": 5.0,
            "intensity": "moderate",
        },
        {
            "external_db_id": "WGER-012",
            "name": "Swimming, freestyle",
            "muscle_group": "Full Body",
            "base_met": 6.0,
            "intensity": "moderate",
        },
        # Parasympathetic activities (maintains_hepatic_perfusion = 1)
        {
            "external_db_id": "WGER-020",
            "name": "Brisk Walk",
            "muscle_group": "Legs",
            "base_met": 3.5,
            "intensity": "low",
        },
        {
            "external_db_id": "WGER-021",
            "name": "Yoga Flow",
            "muscle_group": "Full Body",
            "base_met": 2.5,
            "intensity": "low",
        },
        {
            "external_db_id": "WGER-022",
            "name": "Stretching",
            "muscle_group": "Full Body",
            "base_met": 2.0,
            "intensity": "low",
        },
        # Strength training
        {
            "external_db_id": "WGER-030",
            "name": "Push-ups",
            "muscle_group": "Chest",
            "base_met": 3.8,
            "intensity": "moderate",
        },
        {
            "external_db_id": "WGER-031",
            "name": "Squats",
            "muscle_group": "Legs",
            "base_met": 5.0,
            "intensity": "moderate",
        },
        {
            "external_db_id": "WGER-032",
            "name": "Deadlifts",
            "muscle_group": "Back",
            "base_met": 6.0,
            "intensity": "high",
        },
    ]


# =============================================================================
# MAIN EXECUTION
# =============================================================================
