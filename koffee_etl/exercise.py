"""Koffee ETL submodule: exercise."""

import sqlite3
import uuid
from typing import Any


def process_exercise_data(
    conn: sqlite3.Connection, raw_data_list: list[dict[str, Any]]
) -> int:
    """
    Process and insert exercise data into the database.

    Args:
        conn: SQLite connection
        raw_data_list: List of dictionaries containing raw exercise data

    Returns:
        Number of records inserted
    """
    cursor = conn.cursor()
    inserted_count = 0

    print(f"[INFO] Processing {len(raw_data_list)} exercise records...")

    for raw_data in raw_data_list:
        record_id = raw_data.get("id", str(uuid.uuid4()))

        # Determine hepatic perfusion based on exercise type
        # HIIT defaults to False (shunts blood away from liver)
        # Zone 2, walking, yoga default to True
        maintains_perfusion = raw_data.get(
            "maintains_hepatic_perfusion",
            1 if raw_data.get("intensity", "").lower() != "high" else 0,
        )

        cursor.execute(
            """
            INSERT OR REPLACE INTO exercise_templates (
                id,
                external_db_id,
                name,
                muscle_group,
                base_met,
                maintains_hepatic_perfusion
            ) VALUES (?, ?, ?, ?, ?, ?)
        """,
            (
                record_id,
                raw_data.get("external_db_id"),
                raw_data["name"],
                raw_data["muscle_group"],
                raw_data["base_met"],
                maintains_perfusion,
            ),
        )

        inserted_count += 1

    conn.commit()
    print(f"[INFO] Inserted {inserted_count} exercise records")
    return inserted_count


# =============================================================================
# QUERY FUNCTIONS (For Verification)
# =============================================================================
