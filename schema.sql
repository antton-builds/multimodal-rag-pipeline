-- =========================================================
-- Extensions
-- =========================================================

CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- =========================================================
-- Main table
-- =========================================================

CREATE TABLE slide_rag (
  id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  document_id      TEXT        NOT NULL,
  document_title   TEXT,
  document_topic   TEXT,
  document_summary TEXT,
  slide_number     INT         NOT NULL,
  content_type     TEXT        NOT NULL,
  image_id         TEXT,
  image_url        TEXT,
  image_count      INT         DEFAULT 0,
  links            JSONB,
  content          TEXT        NOT NULL,
  embedding        VECTOR(1536),
  created_at       TIMESTAMP   DEFAULT NOW(),

  CONSTRAINT content_type_check
    CHECK (content_type IN ('text', 'image')),

  CONSTRAINT unique_slide_content
    UNIQUE (document_id, slide_number, content_type, image_id)
);

-- =========================================================
-- Indexes
-- =========================================================

CREATE INDEX slide_rag_embedding_idx
  ON slide_rag
  USING ivfflat (embedding vector_cosine_ops)
  WITH (lists = 100);

CREATE INDEX slide_rag_document_idx
  ON slide_rag(document_id);

CREATE INDEX slide_rag_document_title_idx
  ON slide_rag(document_title);

CREATE INDEX slide_rag_slide_idx
  ON slide_rag(slide_number);

CREATE INDEX slide_rag_content_type_idx
  ON slide_rag(content_type);

-- =========================================================
-- Standard semantic match
-- =========================================================

CREATE FUNCTION match_slide_rag (
  query_embedding VECTOR(1536),
  match_count     INT DEFAULT 5
)
RETURNS TABLE (
  id             UUID,
  document_id    TEXT,
  document_title TEXT,
  document_topic TEXT,
  slide_number   INT,
  content_type   TEXT,
  image_id       TEXT,
  image_url      TEXT,
  content        TEXT,
  similarity     FLOAT
)
LANGUAGE SQL
AS $$
  SELECT
    id,
    document_id,
    document_title,
    document_topic,
    slide_number,
    content_type,
    image_id,
    image_url,
    content,
    1 - (embedding <=> query_embedding) AS similarity
  FROM slide_rag
  WHERE embedding IS NOT NULL
  ORDER BY embedding <=> query_embedding
  LIMIT match_count;
$$;

-- =========================================================
-- Neighbor-aware retrieval
-- =========================================================

CREATE FUNCTION match_with_neighbors (
  query_embedding VECTOR(1536),
  neighbor_range  INT DEFAULT 1
)
RETURNS TABLE (
  id             UUID,
  document_id    TEXT,
  document_title TEXT,
  document_topic TEXT,
  slide_number   INT,
  content_type   TEXT,
  image_id       TEXT,
  image_url      TEXT,
  content        TEXT,
  similarity     FLOAT
)
LANGUAGE plpgsql
AS $$
DECLARE
  best_match RECORD;
BEGIN

  SELECT *
  INTO best_match
  FROM match_slide_rag(query_embedding, 1)
  LIMIT 1;

  RETURN QUERY
  SELECT
    r.id,
    r.document_id,
    r.document_title,
    r.document_topic,
    r.slide_number,
    r.content_type,
    r.image_id,
    r.image_url,
    r.content,
    1 - (r.embedding <=> query_embedding) AS similarity
  FROM slide_rag r
  WHERE r.document_id = best_match.document_id
    AND r.slide_number BETWEEN
        best_match.slide_number - neighbor_range
        AND
        best_match.slide_number + neighbor_range
  ORDER BY r.slide_number;

END;
$$;
