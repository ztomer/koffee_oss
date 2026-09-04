"""Koffee ETL pipeline execution."""

from datetime import UTC, datetime

from .db import DATABASE_NAME, initialize_database
from .exercise import process_exercise_data
from .mock_data import get_mock_exercise_data, get_mock_nutrition_data
from .nutrition import process_nutrition_data
from .schema import create_schema
from .verify import print_sample_data

# =============================================================================
# MAIN EXECUTION
# =============================================================================


def main():
    """
    Main ETL pipeline execution.
    """
    print("=" * 60)
    print("KOFFEE ETL PIPELINE - Offline Data Ingestion")
    print("=" * 60)
    print(f"Started at: {datetime.now(UTC).isoformat()}")
    print()

    # Step 1: Initialize database
    conn = initialize_database(DATABASE_NAME)

    # Step 2: Create schema
    create_schema(conn)

    # Step 3: Ingest mock nutrition data
    nutrition_data = get_mock_nutrition_data()
    process_nutrition_data(conn, nutrition_data)

    # Step 4: Ingest mock exercise data
    exercise_data = get_mock_exercise_data()
    process_exercise_data(conn, exercise_data)

    # Step 5: Verify data
    print_sample_data(conn)

    # Close connection
    conn.close()

    print("\n" + "=" * 60)
    print("ETL PIPELINE COMPLETED SUCCESSFULLY")
    print(f"Output: {DATABASE_NAME}")
    print(f"Finished at: {datetime.now(UTC).isoformat()}")
    print("=" * 60)
