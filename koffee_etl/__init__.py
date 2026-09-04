"""Koffee ETL Pipeline - Offline Data Ingestion
=============================================

This package creates the koffee_reference.sqlite database used for
USDA Nutrition and Wger Exercise data in the Koffee macOS app.

Author: Koffee Data Engineering Team
Version: 1.0.0
"""

from .db import DATABASE_NAME, initialize_database
from .exercise import process_exercise_data
from .mock_data import get_mock_exercise_data, get_mock_nutrition_data
from .nutrition import apply_biological_rules, process_nutrition_data
from .pipeline import main
from .schema import create_schema
from .verify import print_sample_data, verify_fts_search

__all__ = [
    "DATABASE_NAME",
    "apply_biological_rules",
    "create_schema",
    "get_mock_exercise_data",
    "get_mock_nutrition_data",
    "initialize_database",
    "main",
    "print_sample_data",
    "process_exercise_data",
    "process_nutrition_data",
    "verify_fts_search",
]
