-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Initialize demo schema for FormDB Debugger testing

-- Authors table
CREATE TABLE authors (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    email TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Articles table
CREATE TABLE articles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    author_id UUID NOT NULL REFERENCES authors(id),
    content TEXT,
    published_at TIMESTAMP
);

-- Evidence table (for fact-checking)
CREATE TABLE evidence (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    article_id UUID NOT NULL REFERENCES articles(id),
    source_url TEXT NOT NULL,
    prompt_score INTEGER NOT NULL CHECK (prompt_score >= 0 AND prompt_score <= 100),
    verified_at TIMESTAMP
);

-- Add some sample data
INSERT INTO authors (id, name, email, created_at) VALUES
    ('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'Alice Smith', 'alice@example.com', '2024-01-01 10:00:00'),
    ('b1ffcd00-0d1c-5f09-cc7e-7cc0ce491b22', 'Bob Jones', 'bob@example.com', '2024-01-15 14:30:00');

INSERT INTO articles (id, title, author_id, content, published_at) VALUES
    ('c2aade11-1e2d-6a1a-dd8f-8dd1df502c33', 'Introduction to Database Theory', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'This article covers basic concepts...', '2024-02-01 09:00:00'),
    ('d3bbef22-2f3e-7b2b-ee90-9ee2e0613d44', 'Advanced Normalization', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'Building on the basics...', '2024-03-01 10:00:00'),
    ('e4ccf033-3a4f-8c3c-ff01-0ff3f1724e55', 'Query Optimization Tips', 'b1ffcd00-0d1c-5f09-cc7e-7cc0ce491b22', 'Performance matters...', NULL);

INSERT INTO evidence (id, article_id, source_url, prompt_score, verified_at) VALUES
    ('f5dda144-4b5a-9d4d-0012-1004a2835f66', 'c2aade11-1e2d-6a1a-dd8f-8dd1df502c33', 'https://en.wikipedia.org/wiki/Database', 85, '2024-02-02 11:00:00'),
    ('a6eeb255-5c6b-0e5e-1123-2115b3946a77', 'd3bbef22-2f3e-7b2b-ee90-9ee2e0613d44', 'https://www.postgresql.org/docs/', 92, '2024-03-02 12:00:00'),
    ('b7ffc366-6d7c-1f6f-2234-3226c4057b88', 'd3bbef22-2f3e-7b2b-ee90-9ee2e0613d44', 'https://example.com/paper.pdf', 78, NULL);

-- Create an index for common queries
CREATE INDEX idx_articles_author ON articles(author_id);
CREATE INDEX idx_evidence_article ON evidence(article_id);

-- Verify setup
SELECT 'Demo schema initialized successfully' AS status;
SELECT 'Tables: ' || count(*) FROM information_schema.tables WHERE table_schema = 'public';
