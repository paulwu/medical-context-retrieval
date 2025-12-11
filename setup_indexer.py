"""Setup Azure AI Search indexer with Azure OpenAI vectorization.

This creates:
1. Data source pointing to Cosmos DB chunks container
2. Index with vector search capabilities
3. Indexer with Azure OpenAI skill for automatic embedding generation
"""
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from azure.search.documents.indexes import SearchIndexerClient, SearchIndexClient
from azure.search.documents.indexes.models import (
    SearchIndexer,
    SearchIndexerDataContainer,
    SearchIndexerDataSourceConnection,
    SearchIndex,
    SearchField,
    SearchFieldDataType,
    VectorSearch,
    VectorSearchProfile,
    AzureOpenAIVectorizer,
    AzureOpenAIVectorizerParameters,
    HnswAlgorithmConfiguration,
    HnswParameters,
    SemanticConfiguration,
    SemanticPrioritizedFields,
    SemanticField,
    SemanticSearch,
    FieldMapping,
)
from azure.core.credentials import AzureKeyCredential
from rag import config

print("=" * 70)
print("Setup Azure Search Indexer with OpenAI Vectorization")
print("=" * 70)

# Initialize clients
credential = AzureKeyCredential(config.AZURE_SEARCH_KEY)
indexer_client = SearchIndexerClient(config.AZURE_SEARCH_ENDPOINT, credential)
index_client = SearchIndexClient(config.AZURE_SEARCH_ENDPOINT, credential)

# Step 1: Create/update data source
print("\n[1/3] Creating Cosmos DB data source...")
datasource_name = "cosmos-chunks-datasource"

datasource = SearchIndexerDataSourceConnection(
    name=datasource_name,
    type="cosmosdb",
    connection_string=(
        f"AccountEndpoint={config.COSMOS_ENDPOINT};"
        f"AccountKey={config.COSMOS_KEY};"
        f"Database={config.COSMOS_DB_NAME}"
    ),
    container=SearchIndexerDataContainer(name=config.COSMOS_CONTAINER_CHUNKS)
)

try:
    indexer_client.create_or_update_data_source_connection(datasource)
    print(f"      Data source '{datasource_name}' created/updated")
except Exception as e:
    print(f"      Error: {e}")
    sys.exit(1)

# Step 2: Create index with Azure OpenAI vectorizer
print("\n[2/3] Creating index with Azure OpenAI vectorizer...")
index_name = config.AZURE_SEARCH_INDEX_NAME

# Configure Azure OpenAI vectorizer
vectorizer = AzureOpenAIVectorizer(
    vectorizer_name="openai-vectorizer",
    parameters=AzureOpenAIVectorizerParameters(
        resource_url=config.AZURE_OPENAI_ENDPOINT,
        deployment_name=config.AOAI_EMBED_MODEL,
        api_key=config.AZURE_OPENAI_API_KEY,
        model_name="text-embedding-3-large",  # Required in API version 2025-09-01
    )
)

# Define fields
fields = [
    SearchField(
        name="chunk_id",
        type=SearchFieldDataType.String,
        key=True,
        filterable=True,
        sortable=True,
    ),
    SearchField(name="doc_id", type=SearchFieldDataType.String, filterable=True),
    SearchField(name="doc_title", type=SearchFieldDataType.String, searchable=True),
    SearchField(name="raw_chunk", type=SearchFieldDataType.String, searchable=True),
    SearchField(name="ctx_header", type=SearchFieldDataType.String, searchable=True),
    SearchField(name="augmented_chunk", type=SearchFieldDataType.String, searchable=True),
    SearchField(name="section_path", type=SearchFieldDataType.String, filterable=True),
    SearchField(name="source_org", type=SearchFieldDataType.String, filterable=True),
    SearchField(name="source_url", type=SearchFieldDataType.String),
    SearchField(name="pub_date", type=SearchFieldDataType.String, filterable=True),
    SearchField(name="chunk_index", type=SearchFieldDataType.Int32, filterable=True),
    SearchField(
        name="embedding",
        type=SearchFieldDataType.Collection(SearchFieldDataType.Single),
        searchable=True,
        vector_search_dimensions=3072,
        vector_search_profile_name="default-vector-profile",
    ),
]

# Vector search configuration
vector_search = VectorSearch(
    algorithms=[
        HnswAlgorithmConfiguration(
            name="hnsw-config",
            parameters=HnswParameters(
                m=4,
                ef_construction=400,
                ef_search=500,
                metric="cosine"
            )
        )
    ],
    profiles=[
        VectorSearchProfile(
            name="default-vector-profile",
            algorithm_configuration_name="hnsw-config",
            vectorizer_name="openai-vectorizer",
        )
    ],
    vectorizers=[vectorizer]
)

# Semantic search configuration
semantic_config = SemanticConfiguration(
    name="default-semantic-config",
    prioritized_fields=SemanticPrioritizedFields(
        title_field=SemanticField(field_name="doc_title"),
        content_fields=[
            SemanticField(field_name="augmented_chunk"),
            SemanticField(field_name="ctx_header"),
        ]
    )
)

# Create index
index = SearchIndex(
    name=index_name,
    fields=fields,
    vector_search=vector_search,
    semantic_search=SemanticSearch(configurations=[semantic_config])
)

try:
    index_client.create_or_update_index(index)
    print(f"      Index '{index_name}' created/updated")
except Exception as e:
    print(f"      Error: {e}")
    sys.exit(1)

# Step 3: Create indexer
print("\n[3/3] Creating indexer...")
indexer_name = "cosmos-chunks-indexer"

indexer = SearchIndexer(
    name=indexer_name,
    data_source_name=datasource_name,
    target_index_name=index_name,
    field_mappings=[
        FieldMapping(source_field_name="id", target_field_name="chunk_id"),
    ],
)

try:
    indexer_client.create_or_update_indexer(indexer)
    print(f"      Indexer '{indexer_name}' created/updated")
    
    # Run the indexer
    print("\n[Running indexer...]")
    indexer_client.run_indexer(indexer_name)
    print("      Indexer started successfully")
    print("\nIndexer is now running. Check Azure Portal to monitor progress.")
    print("Use: indexer_client.get_indexer_status('cosmos-chunks-indexer') to check status")
    
except Exception as e:
    print(f"      Error: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)

print("\n" + "=" * 70)
print("SUCCESS! Indexer pipeline configured")
print("=" * 70)
