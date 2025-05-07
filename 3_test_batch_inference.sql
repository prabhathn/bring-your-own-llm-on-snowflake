-- STEP 1: Set query tags to easily find in query_history
ALTER SESSION UNSET QUERY_TAG;
ALTER SESSION SET QUERY_TAG = 'llm_vectorization_test';

-- STEP 2: Generate table of N rows with values that will be our prompt seed
CREATE OR REPLACE LOCAL TEMPORARY TABLE IDEA_GENS ON COMMIT PRESERVE ROWS AS
    SELECT
        SNOWFLAKE.CORTEX.COMPLETE(
            'llama3.1-70b',
            [
                {
                    'role': 'user',
                    'content': 'Please give me the name of a country at random. Don''t include any extra commentary, only the name of a country.'
                }
            ],
            {'temperature': 0.7}
        ) AS IDEA_TEXT
    FROM TABLE(GENERATOR(ROWCOUNT => 7000)) t;


-- STEP 3: Call our LLM model and apply it to every row of the table
SELECT
    IDEA_TEXT,
    QWEN_SERVICE!PREDICT(
        CONCAT(
            'What is the capital of this country? Only provide the name of the capital: ',
            IDEA_TEXT:choices[0].messages::VARCHAR
        )
    ) as marketing_idea
FROM IDEA_GENS;
ALTER SESSION UNSET QUERY_TAG;

-- STEP 4: Evaluate performance and batch size (rows / number of invocations)
SELECT
    QUERY_ID,
    QUERY_TEXT,
    QUERY_TYPE,
    DIV0(EXTERNAL_FUNCTION_TOTAL_SENT_ROWS, EXTERNAL_FUNCTION_TOTAL_INVOCATIONS)::INTEGER AS APPROX_BATCH_SIZE,
    TOTAL_ELAPSED_TIME / ROWS_PRODUCED AS TIME_MSEC_PER_ROW,
    TOTAL_ELAPSED_TIME / 1000 AS TOTAL_ELAPSED_TIME_SEC,
    ROWS_PRODUCED,
    EXTERNAL_FUNCTION_TOTAL_SENT_ROWS,
    EXTERNAL_FUNCTION_TOTAL_INVOCATIONS
FROM TABLE(INFORMATION_SCHEMA.QUERY_HISTORY()) 
WHERE
    EXECUTION_STATUS = 'SUCCESS'
    AND QUERY_TYPE IN ('SELECT', 'CREATE_TABLE_AS_SELECT')
    AND QUERY_TAG = 'llm_vectorization_test';