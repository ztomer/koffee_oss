"""Koffee ETL submodule: schema."""

import sqlite3

# =============================================================================
# SCHEMA CREATION
# =============================================================================


def create_schema(conn: sqlite3.Connection) -> None:
    """
    Create all required tables and indexes including FTS5 virtual table.

    Tables:
        - nutrition_templates: USDA nutrition data
        - exercise_templates: Wger exercise data
        - nutrition_fts: FTS5 full-text search index
    """
    cursor = conn.cursor()

    # Create nutrition_templates table
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS nutrition_templates (
            id TEXT PRIMARY KEY,
            external_db_id TEXT,
            name TEXT NOT NULL,
            category TEXT NOT NULL,
            calories REAL NOT NULL,
            protein_g REAL NOT NULL DEFAULT 0,
            carbs_g REAL NOT NULL DEFAULT 0,
            fat_g REAL NOT NULL DEFAULT 0,
            fiber_g REAL NOT NULL DEFAULT 0,
            is_absorption_blocker INTEGER NOT NULL DEFAULT 0,
            requires_fasted_state INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
        )
    """)

    # Create exercise_templates table
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS exercise_templates (
            id TEXT PRIMARY KEY,
            external_db_id TEXT,
            name TEXT NOT NULL,
            muscle_group TEXT NOT NULL,
            base_met REAL NOT NULL,
            maintains_hepatic_perfusion INTEGER NOT NULL DEFAULT 1,
            created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
        )
    """)

    # Create FTS5 virtual table for lightning-fast nutrition search
    # CRITICAL: This enables millisecond search on multi-gigabyte datasets
    cursor.execute("""
        CREATE VIRTUAL TABLE IF NOT EXISTS nutrition_fts USING fts5(
            name,
            category,
            content='nutrition_templates',
            content_rowid='rowid'
        )
    """)

    # Create indexes for common queries
    cursor.execute("""
        CREATE INDEX IF NOT EXISTS idx_nutrition_category 
        ON nutrition_templates(category)
    """)

    cursor.execute("""
        CREATE INDEX IF NOT EXISTS idx_nutrition_calories 
        ON nutrition_templates(calories)
    """)

    cursor.execute("""
        CREATE INDEX IF NOT EXISTS idx_exercise_muscle_group 
        ON exercise_templates(muscle_group)
    """)

    conn.commit()
    print("[INFO] Schema created successfully")


# =============================================================================
# TRANSFORMATION LOGIC (BIOLOGICAL RULES)
# =============================================================================
