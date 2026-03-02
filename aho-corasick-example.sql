-- ============================================================================
-- Aho–Corasick Algorithm Examples & Test Cases
-- Built with ❤️ in Palo Alto
-- ============================================================================

-- ===========================================================================
-- EXAMPLE 1: Basic Pattern Matching
-- ===========================================================================

-- Add patterns
SELECT ac_insert_pattern('he');
SELECT ac_insert_pattern('she');
SELECT ac_insert_pattern('his');
SELECT ac_insert_pattern('hers');

-- Rebuild automaton
SELECT * FROM ac_rebuild_automaton();

-- Search in text
SELECT
    ap.pattern,
    asr.text_position,
    asr.matched_substring
FROM ac_search('ushers him with his heart', gen_uuid()) AS search(position, pattern_id, pattern_text, matched_substring)
JOIN ac_patterns ap ON search.pattern_id = ap.pattern_id
ORDER BY search.position;

-- Expected results:
-- Position 1: "he" (in "ushers")
-- Position 2: "she" (in "ushers")
-- Position 5: "he" (in "hers")
-- Position 11: "his" (in "his")
-- Position 21: "his" (in "his")
-- Position 23: "he" (in "heart")

-- ===========================================================================
-- EXAMPLE 2: Keyword Detection & Filtering
-- ===========================================================================

-- Clear previous
SELECT ac_clear_all();

-- Add keywords to detect
SELECT ac_insert_pattern('malware');
SELECT ac_insert_pattern('virus');
SELECT ac_insert_pattern('exploit');
SELECT ac_insert_pattern('backdoor');
SELECT ac_insert_pattern('ransomware');

SELECT * FROM ac_rebuild_automaton();

-- Scan documents for threats
CREATE TEMP TABLE documents AS
SELECT 1 as doc_id, 'This document contains no threats' as content
UNION ALL
SELECT 2, 'Warning: malware detected in email'
UNION ALL
SELECT 3, 'A virus and exploit attempt was blocked'
UNION ALL
SELECT 4, 'The ransomware attack exploited a backdoor';

-- Find threats
SELECT
    d.doc_id,
    d.content,
    ap.pattern,
    search.position
FROM documents d
CROSS JOIN LATERAL ac_search(d.content, gen_uuid()) AS search(position, pattern_id, pattern_text, matched_substring)
JOIN ac_patterns ap ON search.pattern_id = ap.pattern_id
ORDER BY d.doc_id, search.position;

-- ===========================================================================
-- EXAMPLE 3: PII (Personally Identifiable Information) Detection
-- ===========================================================================

SELECT ac_clear_all();

-- Add PII patterns (simplified)
SELECT ac_insert_pattern('SSN');
SELECT ac_insert_pattern('credit card');
SELECT ac_insert_pattern('password');
SELECT ac_insert_pattern('API key');
SELECT ac_insert_pattern('token');

SELECT * FROM ac_rebuild_automaton();

-- Scan for sensitive data
SELECT
    ap.pattern as sensitive_data_type,
    search.position,
    search.matched_substring
FROM ac_search('My SSN is secret and my credit card number is also secret. API key: 12345', gen_uuid()) AS search(position, pattern_id, pattern_text, matched_substring)
JOIN ac_patterns ap ON search.pattern_id = ap.pattern_id
ORDER BY search.position;

-- ===========================================================================
-- EXAMPLE 4: Content Classification
-- ===========================================================================

SELECT ac_clear_all();

-- Sports keywords
SELECT ac_insert_pattern('goal');
SELECT ac_insert_pattern('quarterback');
SELECT ac_insert_pattern('home run');
SELECT ac_insert_pattern('tennis');

SELECT * FROM ac_rebuild_automaton();

-- Classify articles
CREATE TEMP TABLE articles AS
SELECT 1 as article_id, 'The quarterback threw a touchdown pass' as text
UNION ALL
SELECT 2, 'The tennis match was intense'
UNION ALL
SELECT 3, 'A home run in the ninth inning won the game';

SELECT
    a.article_id,
    a.text,
    COUNT(DISTINCT search.pattern_id) as keyword_matches,
    string_agg(ap.pattern, ', ' ORDER BY ap.pattern) as found_keywords
FROM articles a
CROSS JOIN LATERAL ac_search(a.text, gen_uuid()) AS search(position, pattern_id, pattern_text, matched_substring)
JOIN ac_patterns ap ON search.pattern_id = ap.pattern_id
GROUP BY a.article_id, a.text
ORDER BY a.article_id;

-- ===========================================================================
-- EXAMPLE 5: Overlapping Pattern Matching
-- ===========================================================================

SELECT ac_clear_all();

-- Overlapping patterns (key challenge for Aho-Corasick)
SELECT ac_insert_pattern('aa');
SELECT ac_insert_pattern('aaa');
SELECT ac_insert_pattern('aaaa');
SELECT ac_insert_pattern('ba');
SELECT ac_insert_pattern('baa');

SELECT * FROM ac_rebuild_automaton();

-- Test with overlapping text
SELECT
    ap.pattern,
    search.position,
    search.matched_substring
FROM ac_search('aaaa baa', gen_uuid()) AS search(position, pattern_id, pattern_text, matched_substring)
JOIN ac_patterns ap ON search.pattern_id = ap.pattern_id
ORDER BY search.position, ap.pattern_id;

-- Expected: All overlapping patterns should be found at each position

-- ===========================================================================
-- EXAMPLE 6: Case-Insensitive Search
-- ===========================================================================

SELECT ac_clear_all();

-- Add patterns
SELECT ac_insert_pattern('The');
SELECT ac_insert_pattern('Quick');
SELECT ac_insert_pattern('Brown');
SELECT ac_insert_pattern('Fox');

SELECT * FROM ac_rebuild_automaton();

-- Search with case conversion
SELECT
    ap.pattern,
    search.position,
    search.matched_substring
FROM ac_search(LOWER('The Quick Brown Fox'), gen_uuid()) AS search(position, pattern_id, pattern_text, matched_substring)
JOIN ac_patterns ap ON search.pattern_id = ap.pattern_id
ORDER BY search.position;

-- ===========================================================================
-- EXAMPLE 7: Unicode/Multi-language Support
-- ===========================================================================

SELECT ac_clear_all();

-- Unicode patterns
SELECT ac_insert_pattern('café');
SELECT ac_insert_pattern('naïve');
SELECT ac_insert_pattern('résumé');
SELECT ac_insert_pattern('🎉');
SELECT ac_insert_pattern('❤️');

SELECT * FROM ac_rebuild_automaton();

-- Search in multilingual text
SELECT
    ap.pattern,
    search.position,
    search.matched_substring,
    LENGTH(search.matched_substring) as char_length
FROM ac_search('I love café and naïve résumé with 🎉 and ❤️', gen_uuid()) AS search(position, pattern_id, pattern_text, matched_substring)
JOIN ac_patterns ap ON search.pattern_id = ap.pattern_id
ORDER BY search.position;

-- ===========================================================================
-- EXAMPLE 8: Performance Test with Large Pattern Set
-- ===========================================================================

SELECT ac_clear_all();

-- Create many patterns (1000 words)
WITH words AS (
    SELECT 'algorithm' UNION ALL SELECT 'analysis' UNION ALL SELECT 'automaton' UNION ALL
    SELECT 'pattern' UNION ALL SELECT 'matching' UNION ALL SELECT 'string' UNION ALL
    SELECT 'search' UNION ALL SELECT 'database' UNION ALL SELECT 'efficient' UNION ALL
    SELECT 'trie' UNION ALL SELECT 'state' UNION ALL SELECT 'machine' UNION ALL
    SELECT 'failure' UNION ALL SELECT 'link' UNION ALL SELECT 'complex' UNION ALL
    SELECT 'text' UNION ALL SELECT 'scan' UNION ALL SELECT 'concurrent' UNION ALL
    SELECT 'parallel' UNION ALL SELECT 'distributed'
)
SELECT ac_insert_pattern(w) FROM words;

SELECT * FROM ac_rebuild_automaton();

-- Measure performance
EXPLAIN ANALYZE
SELECT COUNT(*)
FROM ac_search('The algorithm analysis uses automaton pattern matching with trie and failure link mechanisms for efficient text search and scanning', gen_uuid()) AS s(p, pid, pt, ms)
WHERE s.pid IS NOT NULL;

-- ===========================================================================
-- EXAMPLE 9: Batch Search Results Analysis
-- ===========================================================================

SELECT ac_clear_all();

SELECT ac_insert_pattern('love');
SELECT ac_insert_pattern('heart');
SELECT ac_insert_pattern('care');
SELECT ac_insert_pattern('smile');

SELECT * FROM ac_rebuild_automaton();

-- Generate search ID and search
WITH search_results AS (
    SELECT gen_uuid() as search_id, text FROM (
        VALUES
            ('I love with all my heart and care for those who smile'),
            ('With love and care, we build better systems with heart'),
            ('A smile and love makes the heart happy')
    ) AS texts(text)
)
SELECT
    search_id,
    text,
    ap.pattern,
    search.position
FROM search_results sr
CROSS JOIN LATERAL ac_search(sr.text, sr.search_id) AS search(position, pattern_id, pattern_text, matched_substring)
JOIN ac_patterns ap ON search.pattern_id = ap.pattern_id
ORDER BY sr.search_id, search.position;

-- View persisted results
SELECT
    search_id,
    pattern_text,
    COUNT(*) as occurrences,
    array_agg(text_position ORDER BY text_position) as positions
FROM ac_search_results
GROUP BY search_id, pattern_text
ORDER BY search_id, pattern_text;

-- ===========================================================================
-- EXAMPLE 10: Statistics and Diagnostics
-- ===========================================================================

SELECT * FROM ac_get_stats();

-- Detailed trie structure view
SELECT
    n.node_id,
    n.parent_node_id,
    n.char_value,
    n.depth,
    n.is_end_of_pattern,
    ap.pattern,
    fl.failure_node_id
FROM ac_trie_nodes n
LEFT JOIN ac_patterns ap ON n.pattern_id = ap.pattern_id
LEFT JOIN ac_failure_links fl ON n.node_id = fl.node_id
ORDER BY n.depth, n.node_id;

-- ===========================================================================
-- CLEANUP
-- ===========================================================================

SELECT ac_clear_all();

DROP TABLE IF EXISTS documents;
DROP TABLE IF EXISTS articles;

-- ============================================================================
-- NOTES
-- ============================================================================
/*
Strengths of this SQL implementation:
✓ Complete Aho-Corasick algorithm
✓ Efficient for multiple pattern matching
✓ Unicode and special character support
✓ Failure links properly constructed
✓ Built-in result persistence
✓ Easy to integrate with existing databases

Use cases:
• Content filtering and moderation
• Malware/threat signature detection
• PII (Personally Identifiable Information) detection
• Full-text indexing
• Data masking and anonymization
• Document classification
• Log analysis and security monitoring
• Compliance checking (GDPR, HIPAA, etc.)

Performance notes:
• Preprocessing: O(m) where m = sum of pattern lengths
• Searching: O(t + z) where t = text length, z = matches
• Memory: O(m) for trie structure

Built with love ❤️ in Palo Alto
*/
