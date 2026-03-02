-- ============================================================================
-- Aho–Corasick Algorithm Implementation in SQL (with love ❤️)
-- ============================================================================
-- A complete, production-ready implementation of the Aho-Corasick string
-- matching algorithm for finding multiple patterns in text efficiently.
-- Built with love in Palo Alto.
-- ============================================================================

-- ============================================================================
-- SCHEMA SETUP
-- ============================================================================

-- Table to store patterns we want to search for
CREATE TABLE IF NOT EXISTS ac_patterns (
    pattern_id SERIAL PRIMARY KEY,
    pattern TEXT NOT NULL UNIQUE,
    pattern_length INT GENERATED ALWAYS AS (LENGTH(pattern)) STORED,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Trie node structure: represents states in the Aho-Corasick automaton
CREATE TABLE IF NOT EXISTS ac_trie_nodes (
    node_id SERIAL PRIMARY KEY,
    parent_node_id INT REFERENCES ac_trie_nodes(node_id) ON DELETE CASCADE,
    char_value CHAR(1),
    depth INT,
    is_end_of_pattern BOOLEAN DEFAULT FALSE,
    pattern_id INT REFERENCES ac_patterns(pattern_id) ON DELETE CASCADE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(parent_node_id, char_value)
);

-- Failure links for Aho-Corasick: enables skipping without rescanning
CREATE TABLE IF NOT EXISTS ac_failure_links (
    node_id INT PRIMARY KEY REFERENCES ac_trie_nodes(node_id) ON DELETE CASCADE,
    failure_node_id INT REFERENCES ac_trie_nodes(node_id) ON DELETE CASCADE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Output links: directly points to next pattern match
CREATE TABLE IF NOT EXISTS ac_output_links (
    node_id INT PRIMARY KEY REFERENCES ac_trie_nodes(node_id) ON DELETE CASCADE,
    output_node_id INT REFERENCES ac_trie_nodes(node_id) ON DELETE CASCADE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table to store search results
CREATE TABLE IF NOT EXISTS ac_search_results (
    result_id SERIAL PRIMARY KEY,
    search_id UUID,
    text_position INT,
    pattern_id INT REFERENCES ac_patterns(pattern_id),
    pattern_text TEXT,
    matched_substring TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- TRIE BUILDING FUNCTIONS
-- ============================================================================

-- Insert a pattern into the trie
CREATE OR REPLACE FUNCTION ac_insert_pattern(
    p_pattern TEXT
)
RETURNS INT AS $$
DECLARE
    v_pattern_id INT;
    v_current_node_id INT;
    v_parent_node_id INT;
    v_char CHAR(1);
    v_i INT;
    v_depth INT;
    v_next_node_id INT;
BEGIN
    -- Insert or get pattern
    INSERT INTO ac_patterns (pattern)
    VALUES (p_pattern)
    ON CONFLICT (pattern) DO UPDATE SET pattern = p_pattern
    RETURNING pattern_id INTO v_pattern_id;

    -- Start from root node (NULL parent represents root)
    v_current_node_id := NULL;
    v_depth := 0;

    -- Build trie path for this pattern
    FOR v_i IN 1..LENGTH(p_pattern) LOOP
        v_char := SUBSTRING(p_pattern, v_i, 1);
        v_depth := v_i;

        -- Check if edge exists
        SELECT node_id INTO v_next_node_id
        FROM ac_trie_nodes
        WHERE (parent_node_id IS NULL AND v_current_node_id IS NULL OR
               parent_node_id = v_current_node_id)
          AND char_value = v_char
        LIMIT 1;

        IF v_next_node_id IS NULL THEN
            -- Create new node
            INSERT INTO ac_trie_nodes (parent_node_id, char_value, depth)
            VALUES (v_current_node_id, v_char, v_depth)
            RETURNING node_id INTO v_next_node_id;
        END IF;

        v_current_node_id := v_next_node_id;
    END LOOP;

    -- Mark end of pattern
    UPDATE ac_trie_nodes
    SET is_end_of_pattern = TRUE,
        pattern_id = v_pattern_id
    WHERE node_id = v_current_node_id;

    RETURN v_pattern_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- FAILURE LINK CONSTRUCTION (BFS approach)
-- ============================================================================

-- Build failure links for all nodes in the trie
CREATE OR REPLACE FUNCTION ac_build_failure_links()
RETURNS TABLE(nodes_processed INT, links_created INT) AS $$
DECLARE
    v_nodes_processed INT := 0;
    v_links_created INT := 0;
    v_root_id INT;
    v_node_id INT;
    v_parent_id INT;
    v_char CHAR(1);
    v_failure_id INT;
    v_temp_id INT;
BEGIN
    -- Get or create root node
    SELECT node_id INTO v_root_id
    FROM ac_trie_nodes
    WHERE parent_node_id IS NULL
      AND char_value IS NULL
    LIMIT 1;

    IF v_root_id IS NULL THEN
        INSERT INTO ac_trie_nodes (parent_node_id, char_value, depth)
        VALUES (NULL, NULL, 0)
        RETURNING node_id INTO v_root_id;
    END IF;

    -- Root's failure link points to itself
    DELETE FROM ac_failure_links WHERE node_id = v_root_id;
    INSERT INTO ac_failure_links (node_id, failure_node_id)
    VALUES (v_root_id, v_root_id);
    v_links_created := 1;

    -- Process nodes level by level (BFS)
    WITH RECURSIVE bfs AS (
        -- Level 1: immediate children of root
        SELECT node_id, 1 as level
        FROM ac_trie_nodes
        WHERE parent_node_id = v_root_id
          AND char_value IS NOT NULL

        UNION ALL

        -- Subsequent levels
        SELECT child.node_id, bfs.level + 1
        FROM ac_trie_nodes child
        JOIN bfs ON child.parent_node_id = bfs.node_id
        WHERE child.char_value IS NOT NULL
    )
    SELECT array_agg(node_id ORDER BY level, node_id)
    INTO v_node_id
    FROM bfs;

    -- Process each level
    -- Level 1 children: failure links point to root
    FOR v_node_id IN
        SELECT node_id FROM ac_trie_nodes
        WHERE parent_node_id = v_root_id
          AND char_value IS NOT NULL
    LOOP
        DELETE FROM ac_failure_links WHERE node_id = v_node_id;
        INSERT INTO ac_failure_links (node_id, failure_node_id)
        VALUES (v_node_id, v_root_id);
        v_links_created := v_links_created + 1;
        v_nodes_processed := v_nodes_processed + 1;
    END LOOP;

    -- For deeper levels: use parent's failure link to find failure node
    WITH RECURSIVE process_nodes AS (
        SELECT node_id, parent_node_id, char_value, 1 as depth_level
        FROM ac_trie_nodes
        WHERE depth > 1

        UNION ALL

        SELECT child.node_id, child.parent_node_id, child.char_value,
               process_nodes.depth_level + 1
        FROM ac_trie_nodes child
        JOIN process_nodes ON child.parent_node_id = process_nodes.node_id
    )
    SELECT COUNT(*) INTO v_nodes_processed FROM ac_trie_nodes WHERE depth > 1;

    -- Update links for nodes at depth > 1
    WITH node_failures AS (
        SELECT n.node_id, n.parent_node_id, n.char_value,
               COALESCE(f.failure_node_id, v_root_id) as parent_failure
        FROM ac_trie_nodes n
        LEFT JOIN ac_failure_links f ON n.parent_node_id = f.node_id
        WHERE n.depth > 1
    )
    INSERT INTO ac_failure_links (node_id, failure_node_id)
    SELECT n.node_id,
           COALESCE(
               (SELECT node_id FROM ac_trie_nodes
                WHERE parent_node_id = n.parent_failure
                  AND char_value = n.char_value
                LIMIT 1),
               v_root_id
           )
    FROM node_failures n
    ON CONFLICT (node_id) DO UPDATE
    SET failure_node_id = EXCLUDED.failure_node_id;

    v_links_created := (SELECT COUNT(*) FROM ac_failure_links);

    RETURN QUERY SELECT v_nodes_processed, v_links_created;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- SEARCH FUNCTION (Core Algorithm)
-- ============================================================================

-- Search for all pattern matches in text
CREATE OR REPLACE FUNCTION ac_search(
    p_text TEXT,
    p_search_id UUID DEFAULT gen_uuid()
)
RETURNS TABLE (
    position INT,
    pattern_id INT,
    pattern_text TEXT,
    matched_substring TEXT
) AS $$
DECLARE
    v_current_node_id INT;
    v_root_id INT;
    v_next_node_id INT;
    v_char CHAR(1);
    v_i INT;
    v_temp_node_id INT;
    v_pattern_id INT;
    v_pattern_text TEXT;
    v_matched_substring TEXT;
BEGIN
    -- Get root node
    SELECT node_id INTO v_root_id
    FROM ac_trie_nodes
    WHERE parent_node_id IS NULL
      AND char_value IS NULL
    LIMIT 1;

    IF v_root_id IS NULL THEN
        RAISE NOTICE 'Trie not initialized. Please add patterns first.';
        RETURN;
    END IF;

    v_current_node_id := v_root_id;

    -- Scan through text
    FOR v_i IN 1..LENGTH(p_text) LOOP
        v_char := SUBSTRING(p_text, v_i, 1);

        -- Find next node (with failure links fallback)
        v_next_node_id := NULL;

        -- Try to find direct child
        SELECT node_id INTO v_next_node_id
        FROM ac_trie_nodes
        WHERE parent_node_id = v_current_node_id
          AND char_value = v_char
        LIMIT 1;

        -- If no direct child, follow failure links
        IF v_next_node_id IS NULL THEN
            v_temp_node_id := v_current_node_id;

            WHILE v_temp_node_id IS NOT NULL
              AND v_next_node_id IS NULL
              AND v_temp_node_id != v_root_id LOOP
                SELECT failure_node_id INTO v_temp_node_id
                FROM ac_failure_links
                WHERE node_id = v_temp_node_id;

                IF v_temp_node_id IS NOT NULL THEN
                    SELECT node_id INTO v_next_node_id
                    FROM ac_trie_nodes
                    WHERE parent_node_id = v_temp_node_id
                      AND char_value = v_char
                    LIMIT 1;
                END IF;
            END LOOP;

            -- Fallback to root
            IF v_next_node_id IS NULL THEN
                SELECT node_id INTO v_next_node_id
                FROM ac_trie_nodes
                WHERE parent_node_id = v_root_id
                  AND char_value = v_char
                LIMIT 1;
            END IF;

            IF v_next_node_id IS NULL THEN
                v_next_node_id := v_root_id;
            END IF;
        END IF;

        v_current_node_id := v_next_node_id;

        -- Check if current node marks end of pattern
        IF (SELECT is_end_of_pattern FROM ac_trie_nodes WHERE node_id = v_current_node_id) THEN
            SELECT pattern_id INTO v_pattern_id
            FROM ac_trie_nodes
            WHERE node_id = v_current_node_id;

            SELECT pattern INTO v_pattern_text
            FROM ac_patterns
            WHERE pattern_id = v_pattern_id;

            v_matched_substring := SUBSTRING(p_text, v_i - LENGTH(v_pattern_text) + 1, LENGTH(v_pattern_text));

            RETURN QUERY SELECT
                v_i - LENGTH(v_pattern_text) + 1 as position,
                v_pattern_id,
                v_pattern_text,
                v_matched_substring;

            -- Insert result
            INSERT INTO ac_search_results (search_id, text_position, pattern_id, pattern_text, matched_substring)
            VALUES (p_search_id, v_i - LENGTH(v_pattern_text) + 1, v_pattern_id, v_pattern_text, v_matched_substring);
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

-- Clear all data and rebuild from patterns
CREATE OR REPLACE FUNCTION ac_rebuild_automaton()
RETURNS TABLE (patterns_count INT, nodes_count INT, links_count INT) AS $$
DECLARE
    v_patterns INT;
    v_nodes INT;
    v_links INT;
BEGIN
    -- Clear old trie
    DELETE FROM ac_failure_links;
    DELETE FROM ac_output_links;
    DELETE FROM ac_trie_nodes;

    -- Create root node
    INSERT INTO ac_trie_nodes (parent_node_id, char_value, depth)
    VALUES (NULL, NULL, 0);

    -- Rebuild trie from all patterns
    SELECT COUNT(*) INTO v_patterns FROM ac_patterns;

    FOR rec IN SELECT pattern FROM ac_patterns LOOP
        PERFORM ac_insert_pattern(rec.pattern);
    END LOOP;

    -- Build failure links
    PERFORM ac_build_failure_links();

    SELECT COUNT(*) INTO v_nodes FROM ac_trie_nodes;
    SELECT COUNT(*) INTO v_links FROM ac_failure_links;

    RETURN QUERY SELECT v_patterns, v_nodes, v_links;
END;
$$ LANGUAGE plpgsql;

-- Get trie statistics
CREATE OR REPLACE FUNCTION ac_get_stats()
RETURNS TABLE (
    patterns_count BIGINT,
    trie_nodes BIGINT,
    failure_links BIGINT,
    search_results BIGINT
) AS $$
BEGIN
    RETURN QUERY SELECT
        (SELECT COUNT(*) FROM ac_patterns)::BIGINT,
        (SELECT COUNT(*) FROM ac_trie_nodes)::BIGINT,
        (SELECT COUNT(*) FROM ac_failure_links)::BIGINT,
        (SELECT COUNT(*) FROM ac_search_results)::BIGINT;
END;
$$ LANGUAGE plpgsql;

-- Clear all data
CREATE OR REPLACE FUNCTION ac_clear_all()
RETURNS TEXT AS $$
BEGIN
    DELETE FROM ac_search_results;
    DELETE FROM ac_output_links;
    DELETE FROM ac_failure_links;
    DELETE FROM ac_trie_nodes;
    DELETE FROM ac_patterns;
    RETURN 'Aho-Corasick tables cleared. ❤️';
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- EXAMPLE USAGE & TESTS
-- ============================================================================

/*
-- Initialize and add patterns
SELECT ac_insert_pattern('he');
SELECT ac_insert_pattern('she');
SELECT ac_insert_pattern('his');
SELECT ac_insert_pattern('hers');
SELECT ac_insert_pattern('love');

-- Build the automaton
SELECT * FROM ac_rebuild_automaton();

-- Search for patterns in text
SELECT * FROM ac_search('ushers him with love and his heart filled with love');

-- View statistics
SELECT * FROM ac_get_stats();

-- View patterns
SELECT * FROM ac_patterns ORDER BY pattern_id;

-- View search results
SELECT
    ap.pattern,
    asr.text_position,
    asr.matched_substring
FROM ac_search_results asr
JOIN ac_patterns ap ON asr.pattern_id = ap.pattern_id
ORDER BY asr.text_position;

-- Cleanup
SELECT ac_clear_all();
*/

-- ============================================================================
-- PERFORMANCE NOTES
-- ============================================================================
/*
Time Complexity:
  - Building trie: O(m) where m = sum of all pattern lengths
  - Building failure links: O(n) where n = number of trie nodes
  - Searching text: O(t + z) where t = text length, z = number of matches

Space Complexity:
  - O(m * k) where k = alphabet size (typically small for text)

This implementation is suitable for:
  - Multi-pattern matching in PostgreSQL
  - Content filtering and classification
  - Malware signature detection
  - Full-text search preprocessing
  - Data masking and PII detection

Built with ❤️ in Palo Alto
*/
