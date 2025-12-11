"""Test script for Azure AI Search integration.

This script validates that the Azure Search configuration is correct
and the index can be created successfully.
"""
import os
import sys
from pathlib import Path

# Add project root to path
sys.path.insert(0, str(Path(__file__).parent))

from rag import config, azure_search

def test_azure_search_config():
    """Test that Azure Search is configured."""
    print("Testing Azure Search configuration...")
    print(f"  AZURE_SEARCH_ENDPOINT: {config.AZURE_SEARCH_ENDPOINT}")
    print(f"  AZURE_SEARCH_INDEX_NAME: {config.AZURE_SEARCH_INDEX_NAME}")
    print(f"  AZURE_SEARCH_KEY: {'*' * 10 if config.AZURE_SEARCH_KEY else 'NOT SET'}")

    if not config.AZURE_SEARCH_ENDPOINT or not config.AZURE_SEARCH_KEY:
        print("\n[FAIL] Azure Search is not configured!")
        print("Please set AZURE_SEARCH_ENDPOINT and AZURE_SEARCH_KEY in your .env file")
        return False

    print("[PASS] Azure Search configuration found")
    return True

def test_create_index():
    """Test creating the Azure Search index."""
    print("\nTesting Azure Search index creation...")
    try:
        azure_search.create_search_index(embedding_dimensions=3072)
        print("[PASS] Index created successfully")
        return True
    except Exception as e:
        print(f"[FAIL] Failed to create index: {e}")
        return False

def test_get_document_count():
    """Test getting document count from index."""
    print("\nTesting document count retrieval...")
    try:
        count = azure_search.get_document_count()
        print(f"[PASS] Index contains {count} documents")
        return True
    except Exception as e:
        print(f"[FAIL] Failed to get document count: {e}")
        return False

def main():
    """Run all tests."""
    print("=" * 60)
    print("Azure AI Search Integration Test")
    print("=" * 60)

    # Check storage mode
    print(f"\nCurrent STORAGE_MODE: {config.STORAGE_MODE}")
    if config.STORAGE_MODE != "azure":
        print("\n[WARNING] STORAGE_MODE is not set to 'azure'")
        print("          Set STORAGE_MODE=azure in .env to use Azure Search")

    # Run tests
    tests_passed = 0
    tests_total = 3

    if test_azure_search_config():
        tests_passed += 1
    else:
        print("\n[WARNING] Skipping remaining tests due to missing configuration")
        return

    if test_create_index():
        tests_passed += 1

    if test_get_document_count():
        tests_passed += 1

    # Summary
    print("\n" + "=" * 60)
    print(f"Tests Passed: {tests_passed}/{tests_total}")
    print("=" * 60)

    if tests_passed == tests_total:
        print("\n[SUCCESS] All tests passed! Azure Search is ready to use.")
    else:
        print(f"\n[FAIL] {tests_total - tests_passed} test(s) failed.")

if __name__ == "__main__":
    main()
