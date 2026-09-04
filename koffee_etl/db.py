"""Koffee ETL submodule: database initialization."""

import sqlite3

# =============================================================================
# DATABASE INITIALIZATION
# =============================================================================


def initialize_database(db_path: str) -> sqlite3.Connection:
    """
    Initialize SQLite database with performance-optimized PRAGMAs.

    Args:
        db_path: Path to the SQLite database file

    Returns:
        SQLite connection object
    """
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row

    # Enable WAL mode for better concurrent read/write performance
    conn.execute("PRAGMA journal_mode = WAL")

    # NORMAL synchronous provides good balance of safety and speed
    conn.execute("PRAGMA synchronous = NORMAL")

    # Optimize for read-heavy workloads
    conn.execute("PRAGMA cache_size = -64000")  # 64MB cache
    conn.execute("PRAGMA temp_store = MEMORY")

    print(f"[INFO] Database initialized: {db_path}")
    return conn


# =============================================================================
# SCHEMA CREATION
# =============================================================================


# =============================================================================
# CONFIGURATION
# =============================================================================

DATABASE_NAME = "koffee_reference.sqlite"
