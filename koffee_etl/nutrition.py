"""Koffee ETL submodule: nutrition."""

import sqlite3
import uuid
from typing import Any

# =============================================================================
# TRANSFORMATION LOGIC (BIOLOGICAL RULES)
# =============================================================================


def apply_biological_rules(nutrition_data: dict[str, Any]) -> dict[str, Any]:
    """
    Apply biological rules to nutrition data during ingestion.

    Rules:
        1. Fiber Firewall: If fiber_g > 5.0, set is_absorption_blocker = 1
           (High fiber blocks absorption of caffeine and other nootropics)

        2. Amino Acid Competition: If protein_g > 20.0, set requires_fasted_state = 0
           (High protein meals actually HELP absorption by providing transport carriers)

    Args:
        nutrition_data: Raw nutrition data dictionary

    Returns:
        Transformed nutrition data with biological rules applied
    """
    # Make a copy to avoid mutating original
    transformed = nutrition_data.copy()

    fiber_g = transformed.get("fiber_g", 0)
    protein_g = transformed.get("protein_g", 0)

    # Rule 1: Fiber Firewall
    if fiber_g > 5.0:
        transformed["is_absorption_blocker"] = 1
        print(
            f"[BIOLOGICAL] Fiber Firewall activated: {transformed['name']} "
            f"(fiber_g={fiber_g}g > 5.0g)"
        )
    else:
        transformed["is_absorption_blocker"] = 0

    # Rule 2: Amino Acid Competition
    if protein_g > 20.0:
        transformed["requires_fasted_state"] = 0
        print(
            f"[BIOLOGICAL] Amino Acid Carrier Effect: {transformed['name']} "
            f"(protein_g={protein_g}g > 20g)"
        )
    else:
        # Default: some high-caffeine items need fasted state
        transformed["requires_fasted_state"] = transformed.get(
            "requires_fasted_state", 0
        )

    return transformed


def process_nutrition_data(
    conn: sqlite3.Connection, raw_data_list: list[dict[str, Any]]
) -> int:
    """
    Process and insert nutrition data into the database with biological rule transformation.

    This function:
        1. Iterates through raw data
        2. Applies biological rules (Fiber Firewall, Amino Acid Competition)
        3. Generates UUIDs for new records
        4. Inserts into database
        5. Updates FTS5 index

    Args:
        conn: SQLite connection
        raw_data_list: List of dictionaries containing raw nutrition data

    Returns:
        Number of records inserted
    """
    cursor = conn.cursor()
    inserted_count = 0

    print(f"[INFO] Processing {len(raw_data_list)} nutrition records...")

    for raw_data in raw_data_list:
        # Apply biological transformation rules
        transformed = apply_biological_rules(raw_data)

        # Generate UUID if not provided
        record_id = transformed.get("id", str(uuid.uuid4()))

        # Insert record
        cursor.execute(
            """
            INSERT OR REPLACE INTO nutrition_templates (
                id,
                external_db_id,
                name,
                category,
                calories,
                protein_g,
                carbs_g,
                fat_g,
                fiber_g,
                is_absorption_blocker,
                requires_fasted_state
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
            (
                record_id,
                transformed.get("external_db_id"),
                transformed["name"],
                transformed["category"],
                transformed["calories"],
                transformed.get("protein_g", 0),
                transformed.get("carbs_g", 0),
                transformed.get("fat_g", 0),
                transformed.get("fiber_g", 0),
                transformed["is_absorption_blocker"],
                transformed["requires_fasted_state"],
            ),
        )

        inserted_count += 1

    # Rebuild FTS5 index to ensure searchability
    cursor.execute("INSERT INTO nutrition_fts(nutrition_fts) VALUES('rebuild')")

    conn.commit()
    print(f"[INFO] Inserted {inserted_count} nutrition records")
    return inserted_count
