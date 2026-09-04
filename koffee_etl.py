#!/usr/bin/env python3
"""
Koffee ETL Pipeline - Offline Data Ingestion Script
=====================================================
Launcher: the implementation lives in the koffee_etl package.
This script creates the koffee_reference.sqlite database used for
USDA Nutrition and Wger Exercise data in the Koffee macOS app.

Author: Koffee Data Engineering Team
Version: 1.0.0
"""

from koffee_etl.pipeline import main

if __name__ == "__main__":
    main()
