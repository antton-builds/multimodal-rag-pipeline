# multimodal-rag-pipeline
A multimodal RAG pipeline built with n8n that extracts text and images from presentations using OCR and vision AI, stores vector embeddings in Supabase, and serves answers through a Telegram AI agent.

## Overview

Most RAG pipelines index text only. This pipeline captures the full content of each presentation slide — including charts, diagrams, and images — making all visual content semantically searchable alongside text. Users can query the knowledge base in natural language through Telegram and receive grounded, cited answers with direct links to relevant slide images.

## Architecture

### Ingestion Pipeline
1. Presentation files are fetched from Google Drive
2. Mistral OCR extracts text and images from each slide
3. An LLM generates a topic label and summary for each presentation based on the first 3 slides
4. Slide text is cleaned, embedded, and enriched with document-level metadata
5. Images are uploaded to Supabase Storage and analyzed by Pixtral vision AI
6. Vision descriptions are embedded and stored alongside image URLs
7. All vectors are inserted into Supabase pgvector

### RAG Retrieval Agent — Telegram Interface

Flow:
1. Telegram Trigger receives user question
2. Query Expansion LLM generates 2 additional search queries
3. Code node parses LLM output and appends original question → 3 queries total
4. All 3 queries are embedded
5. All 3 queries are searched against Supabase pgvector
6. Code forms a coherent user's message for LLM
7. AI Agent synthesizes a grounded answer with slide citations and image URLs
8. Response is sent back to Telegram

## Stack

| Component | Technology |
|---|---|
| Orchestration | n8n |
| OCR | Mistral OCR |
| Vision AI | Mistral Pixtral 12B |
| Text Embeddings | OpenAI text-embedding-3-small |
| Image Embeddings | OpenAI text-embedding-3-small |
| Vector Database | Supabase pgvector |
| Image Storage | Supabase Storage |
| Retrieval Agent | GPT-4o-mini |
| Interface | Telegram Bot |

## Key Design Decisions

**Multimodal indexing** — Images are described by a vision model and embedded separately from slide text. This allows users to retrieve relevant visuals even without knowing they exist.

**Document-level metadata** — Each slide inherits a topic label and summary generated from the presentation's first 3 slides. This gives the retrieval agent both slide-level detail and broader document context.

**Query expansion** — Each user query is expanded into 3 semantic variations before retrieval, improving recall without sacrificing precision.

**Extensible architecture** — The pipeline is built for presentations but supports any document type. Switching to PDFs, Word documents, or web pages requires only changes to the ingestion and chunking logic.

## Workflow Files

| File | Description |
|---|---|
| `rag-ingestion-pipeline.json` | Processes presentation files into the vector database |
| `rag-retrieval-agent.json` | Handles Telegram queries and returns cited answers |

## Setup

### Prerequisites
- n8n instance (self-hosted or cloud)
- Supabase project with pgvector extension enabled
- Mistral AI API key
- OpenAI API key
- Telegram Bot token
- Google Drive API credentials

### Installation
1. Import both workflow JSON files into your n8n instance
2. Configure credentials for all services
3. Run the SQL schema setup in Supabase
4. Add presentation files to your Google Drive folder
5. Run the ingestion pipeline
6. Start the retrieval agent workflow

### Supabase Setup
Enable the pgvector extension in your Supabase project:
```sql
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS pgcrypto;
```

## License
MIT
