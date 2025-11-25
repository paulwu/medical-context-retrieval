#!/usr/bin/env python3
"""
Standalone Azure Search Indexer Setup for Cloud Shell
No dependencies on local modules - uses only environment variables
"""
import os
import sys

# Get configuration from environment variables
COSMOS_ENDPOINT = os.getenv('COSMOS_ENDPOINT')
COSMOS_KEY = os.getenv('COSMOS_KEY')
COSMOS_DB_NAME = os.getenv('COSMOS_DB_NAME', 'medical-context-db')
COSMOS_CONTAINER_CHUNKS = os.getenv('COSMOS_CONTAINER_CHUNKS', 'chunks')
AZURE_SEARCH_ENDPOINT = os.getenv('AZURE_SEARCH_ENDPOINT')
AZURE_SEARCH_KEY = os.getenv('AZURE_SEARCH_KEY')
AZURE_SEARCH_INDEX_NAME = os.getenv('AZURE_SEARCH_INDEX_NAME', 'medical-context-index')
AZURE_OPENAI_ENDPOINT = os.getenv('AZURE_OPENAI_ENDPOINT')
AZURE_OPENAI_API_KEY = os.getenv('AZURE_OPENAI_API_KEY')
AOAI_EMBED_MODEL = os.getenv('AOAI_EMBED_MODEL', 'text-embedding-3-large')

# Validate required variables
required = {
    'COSMOS_ENDPOINT': COSMOS_ENDPOINT,
    'COSMOS_KEY': COSMOS_KEY,
    'AZURE_SEARCH_ENDPOINT': AZURE_SEARCH_ENDPOINT,
    'AZURE_SEARCH_KEY': AZURE_SEARCH_KEY,
    'AZURE_OPENAI_ENDPOINT': AZURE_OPENAI_ENDPOINT,
    'AZURE_OPENAI_API_KEY': AZURE_OPENAI_API_KEY,
}

missing = [k for k, v in required.items() if not v]
if missing:
    print("ERROR: Missing required environment variables:")
    for var in missing:
        print(f"  - {var}")
    print("\nSet them with: export VARIABLE_NAME=value")
    sys.exit(1)

try:
    from azure.search.documents.indexes import SearchIndexClient, SearchIndexerClient
    from azure.search.documents.indexes.models import (
        SearchIndex, SearchField, SearchFieldDataType,
        VectorSearch, HnswAlgorithmConfiguration, VectorSearchProfile,
        SemanticConfiguration, SemanticPrioritizedFields, SemanticField, SemanticSearch,
        SearchIndexerDataSourceConnection, SearchIndexerDataContainer,
        SearchIndexer, FieldMapping, OutputFieldMappingEntry,
        SearchIndexerSkillset, AzureOpenAIEmbeddingSkill, InputFieldMappingEntry
    )
    from azure.core.credentials import AzureKeyCredential
except ImportError:
    print("ERROR: Azure SDK not installed")
    print("Run: pip install --user azure-search-documents")
    sys.exit(1)


def create_index():
    """Create Azure Search index with vector field"""
    print("\n[Step 1/4] Creating Azure Search index...")

    client = SearchIndexClient(
        endpoint=AZURE_SEARCH_ENDPOINT,
        credential=AzureKeyCredential(AZURE_SEARCH_KEY)
    )

    # Define fields
    fields = [
        SearchField(name="id", type=SearchFieldDataType.String, key=True, searchable=False),
        SearchField(name="chunk_id", type=SearchFieldDataType.String, searchable=False, filterable=True),
        SearchField(name="doc_id", type=SearchFieldDataType.String, searchable=False, filterable=True),
        SearchField(name="doc_title", type=SearchFieldDataType.String, searchable=True, filterable=True),
        SearchField(name="raw_chunk", type=SearchFieldDataType.String, searchable=True),
        SearchField(name="ctx_header", type=SearchFieldDataType.String, searchable=True),
        SearchField(name="augmented_chunk", type=SearchFieldDataType.String, searchable=True),
        SearchField(name="section_path", type=SearchFieldDataType.String, searchable=False, filterable=True),
        SearchField(name="source_org", type=SearchFieldDataType.String, searchable=False, filterable=True),
        SearchField(name="source_url", type=SearchFieldDataType.String, searchable=False),
        SearchField(name="pub_date", type=SearchFieldDataType.String, searchable=False, filterable=True),
        SearchField(name="chunk_index", type=SearchFieldDataType.Int32, searchable=False, filterable=True, sortable=True),
        SearchField(
            name="embedding",
            type=SearchFieldDataType.Collection(SearchFieldDataType.Single),
            searchable=True,
            vector_search_dimensions=3072,
            vector_search_profile_name="medical-context-vector-profile"
        )
    ]

    # Configure vector search
    vector_search = VectorSearch(
        algorithms=[
            HnswAlgorithmConfiguration(
                name="medical-context-hnsw",
                parameters={
                    "m": 4,
                    "efConstruction": 400,
                    "efSearch": 500,
                    "metric": "cosine"
                }
            )
        ],
        profiles=[
            VectorSearchProfile(
                name="medical-context-vector-profile",
                algorithm_configuration_name="medical-context-hnsw"
            )
        ]
    )

    # Configure semantic search
    semantic_config = SemanticConfiguration(
        name="medical-semantic-config",
        prioritized_fields=SemanticPrioritizedFields(
            title_field=SemanticField(field_name="doc_title"),
            content_fields=[
                SemanticField(field_name="augmented_chunk"),
                SemanticField(field_name="ctx_header")
            ]
        )
    )

    semantic_search = SemanticSearch(configurations=[semantic_config])

    # Create index
    index = SearchIndex(
        name=AZURE_SEARCH_INDEX_NAME,
        fields=fields,
        vector_search=vector_search,
        semantic_search=semantic_search
    )

    result = client.create_or_update_index(index)
    print(f"✓ Index '{result.name}' created/updated")


def create_data_source():
    """Create Cosmos DB data source for indexer"""
    print("\n[Step 2/4] Creating Cosmos DB data source...")

    client = SearchIndexerClient(
        endpoint=AZURE_SEARCH_ENDPOINT,
        credential=AzureKeyCredential(AZURE_SEARCH_KEY)
    )

    # Cosmos DB connection string format
    cosmos_connection_string = (
        f"AccountEndpoint={COSMOS_ENDPOINT};"
        f"AccountKey={COSMOS_KEY};"
        f"Database={COSMOS_DB_NAME}"
    )

    # Create data source
    data_source = SearchIndexerDataSourceConnection(
        name="cosmos-chunks-datasource",
        type="cosmosdb",
        connection_string=cosmos_connection_string,
        container=SearchIndexerDataContainer(
            name=COSMOS_CONTAINER_CHUNKS,
            query=None  # Index all documents
        ),
        data_change_detection_policy={
            "@odata.type": "#Microsoft.Azure.Search.HighWaterMarkChangeDetectionPolicy",
            "highWaterMarkColumnName": "_ts"
        }
    )

    result = client.create_or_update_data_source_connection(data_source)
    print(f"✓ Data source '{result.name}' created")
    print(f"  Connected to: {COSMOS_DB_NAME}/{COSMOS_CONTAINER_CHUNKS}")


def create_skillset():
    """Create skillset with Azure OpenAI embedding skill"""
    print("\n[Step 3/4] Creating skillset with Azure OpenAI embedding...")

    client = SearchIndexerClient(
        endpoint=AZURE_SEARCH_ENDPOINT,
        credential=AzureKeyCredential(AZURE_SEARCH_KEY)
    )

    # Azure OpenAI embedding skill
    embedding_skill = AzureOpenAIEmbeddingSkill(
        name="azure-openai-embedding-skill",
        description="Generate embeddings using Azure OpenAI",
        context="/document",
        resource_url=AZURE_OPENAI_ENDPOINT,
        api_key=AZURE_OPENAI_API_KEY,
        deployment_name=AOAI_EMBED_MODEL,
        model_name="text-embedding-3-large",
        dimensions=3072,
        inputs=[
            InputFieldMappingEntry(
                name="text",
                source="/document/augmented_chunk"
            )
        ],
        outputs=[
            {"name": "embedding", "targetName": "embedding"}
        ]
    )

    # Create skillset
    skillset = SearchIndexerSkillset(
        name="medical-context-skillset",
        description="Generate embeddings for medical context chunks",
        skills=[embedding_skill]
    )

    result = client.create_or_update_skillset(skillset)
    print(f"✓ Skillset '{result.name}' created")
    print(f"  Using model: {AOAI_EMBED_MODEL}")


def create_indexer():
    """Create indexer to connect Cosmos DB to Search Index"""
    print("\n[Step 4/4] Creating indexer...")

    client = SearchIndexerClient(
        endpoint=AZURE_SEARCH_ENDPOINT,
        credential=AzureKeyCredential(AZURE_SEARCH_KEY)
    )

    # Create indexer
    # Note: No field mappings needed! Azure auto-maps:
    # - Cosmos DB fields to index fields by name
    # - Skillset outputs to index fields by name
    indexer = SearchIndexer(
        name="cosmos-chunks-indexer",
        description="Index medical context chunks from Cosmos DB",
        data_source_name="cosmos-chunks-datasource",
        target_index_name=AZURE_SEARCH_INDEX_NAME,
        skillset_name="medical-context-skillset",
        parameters={
            "batchSize": 100,
            "maxFailedItems": 10,
            "maxFailedItemsPerBatch": 5
        }
    )

    result = client.create_or_update_indexer(indexer)
    print(f"✓ Indexer '{result.name}' created")
    print(f"  Status: Will begin indexing automatically")

    # Run the indexer immediately
    print("\n  Running indexer now...")
    client.run_indexer(result.name)
    print("  ✓ Indexer started")


def check_indexer_status():
    """Check indexer execution status"""
    print("\n[Checking Status]")

    client = SearchIndexerClient(
        endpoint=AZURE_SEARCH_ENDPOINT,
        credential=AzureKeyCredential(AZURE_SEARCH_KEY)
    )

    status = client.get_indexer_status("cosmos-chunks-indexer")

    print(f"  Indexer state: {status.last_result.status if status.last_result else 'Not run yet'}")

    if status.last_result:
        print(f"  Items processed: {status.last_result.item_count}")
        print(f"  Errors: {status.last_result.failed_item_count}")


def main():
    print("=" * 70)
    print("AZURE AI SEARCH INDEXER SETUP")
    print("Automatic indexing from Cosmos DB with Azure OpenAI embeddings")
    print("=" * 70)

    print(f"\nConfiguration:")
    print(f"  Cosmos DB: {COSMOS_ENDPOINT}")
    print(f"  Container: {COSMOS_CONTAINER_CHUNKS}")
    print(f"  Search Index: {AZURE_SEARCH_INDEX_NAME}")
    print(f"  Embedding Model: {AOAI_EMBED_MODEL}")

    try:
        # Create all components
        create_index()
        create_data_source()
        create_skillset()
        create_indexer()

        # Check status
        import time
        print("\nWaiting 10 seconds for indexer to start...")
        time.sleep(10)
        check_indexer_status()

        print("\n" + "=" * 70)
        print("SETUP COMPLETE! ✓")
        print("=" * 70)
        print("\n📊 What happens next:")
        print("  • Indexer automatically pulls chunks from Cosmos DB")
        print("  • Azure OpenAI generates embeddings for each chunk")
        print("  • Search index is populated with vectors")
        print("  • Process runs automatically on a schedule")
        print("\n⏱️  Initial indexing time: ~10-15 minutes for 762 chunks")
        print("\n🔍 Monitor progress:")
        print("  • Azure Portal → Search service → Indexers")
        print("=" * 70)

    except Exception as e:
        print(f"\n❌ Error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()
