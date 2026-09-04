"""Koffee ETL submodule: verify."""

import sqlite3

# =============================================================================
# QUERY FUNCTIONS (For Verification)
# =============================================================================


def verify_fts_search(conn: sqlite3.Connection, search_term: str) -> list[dict]:
    """
    Verify FTS5 search is working correctly.

    Args:
        conn: SQLite connection
        search_term: Term to search for

    Returns:
        List of matching records
    """
    cursor = conn.cursor()
    cursor.execute(
        """
        SELECT n.* FROM nutrition_templates n
        JOIN nutrition_fts f ON n.rowid = f.rowid
        WHERE nutrition_fts MATCH ?
    """,
        (search_term,),
    )

    return [dict(row) for row in cursor.fetchall()]


def print_sample_data(conn: sqlite3.Connection) -> None:
    """Print sample data from each table for verification."""
    cursor = conn.cursor()

    print("\n" + "=" * 60)
    print("SAMPLE DATA VERIFICATION")
    print("=" * 60)

    # Sample nutrition data
    print("\n[Nutrition] Sample records:")
    cursor.execute("SELECT * FROM nutrition_templates LIMIT 5")
    for row in cursor.fetchall():
        print(
            f"  - {row['name']} ({row['category']}): "
            f"{row['calories']}cal, {row['protein_g']}g protein, "
            f"fiber={row['fiber_g']}g, blocker={row['is_absorption_blocker']}"
        )

    # Sample exercise data
    print("\n[Exercise] Sample records:")
    cursor.execute("SELECT * FROM exercise_templates LIMIT 5")
    for row in cursor.fetchall():
        print(
            f"  - {row['name']} ({row['muscle_group']}): "
            f"MET={row['base_met']}, hepatic={row['maintains_hepatic_perfusion']}"
        )

    # FTS5 verification
    print("\n[FTS5] Search test for 'chicken':")
    results = verify_fts_search(conn, "chicken")
    for r in results[:3]:
        print(f"  - {r['name']}")

    # Stats
    print("\n[Stats] Database statistics:")
    cursor.execute("SELECT COUNT(*) as count FROM nutrition_templates")
    print(f"  Nutrition records: {cursor.fetchone()['count']}")
    cursor.execute("SELECT COUNT(*) as count FROM exercise_templates")
    print(f"  Exercise records: {cursor.fetchone()['count']}")


# =============================================================================
# MOCK DATA (For Demonstration)
# =============================================================================
