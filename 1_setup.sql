////////////////////////////////////////////////////////////////////////////////////////////////////
// QWEN TEST DEMO
// This is the set-up script for the Qwen test demo
//
// There are a few general steps
// 1. Create a new role with appropriate privileges
// 2. Create compute engines
// 3. Create external integrations to access external resources like huggingface, pypi
////////////////////////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////////////////////////
// STEP 0 - CLEAN-UP & UTILITY FUNCTIONS - !*!*!*!*! DO NOT RUN AS PART OF SCRIPT !*!*!*!*!
// These are simple utility functions for cleanup/removal of the assets that are created 
// in this demo.
////////////////////////////////////////////////////////////////////////////////////////////////////

-- View created resources
SHOW COMPUTE POOLS;
SHOW EXTERNAL ACCESS INTEGRATIONS;
SHOW NETWORK RULES;
SHOW SERVICES;
SHOW MODELS;

SELECT SYSTEM$GET_SERVICE_LOGS('QWEN_SERVICE', 0, 'model-inference', 10);

-- Turn off compute and services resources
ALTER COMPUTE POOL QWEN_POOL_S STOP ALL;
ALTER COMPUTE POOL QWEN_POOL_S SUSPEND;

ALTER SERVICE QWEN_SERVICE SUSPEND;

-- Drop all resources
USE ROLE ACCOUNTADMIN;
DROP EXTERNAL ACCESS INTEGRATION PYPI_ACCESS_INTEGRATION;
DROP NETWORK RULE PYPI_NETWORK_RULE;
DROP EXTERNAL ACCESS INTEGRATION HUGGINGFACE_ACCESS_INTEGRATION;
DROP NETWORK RULE HUGGINGFACE_NETWORK_RULE;
DROP EXTERNAL ACCESS INTEGRATION WIKIMEDIA_ACCESS_INTEGRATION;
DROP NETWORK RULE WIKIMEDIA_NETWORK_RULE;
DROP COMPUTE POOL QWEN_POOL_S;
DROP SCHEMA TEST_QWEN_SCHEMA;
DROP DATABASE TEST_QWEN_DB;


////////////////////////////////////////////////////////////////////////////////////////////////////
// STEP 1
// Create a new role and db / schema and object permission
// Why? ACCOUNTADMIN roles are not permitted to access compute pools directly
////////////////////////////////////////////////////////////////////////////////////////////////////

USE ROLE ACCOUNTADMIN;
CREATE ROLE IF NOT EXISTS QWEN_TEST_ROLE;

GRANT CREATE DATABASE ON ACCOUNT TO ROLE QWEN_TEST_ROLE;
GRANT CREATE WAREHOUSE ON ACCOUNT TO ROLE QWEN_TEST_ROLE;
GRANT CREATE COMPUTE POOL ON ACCOUNT TO ROLE QWEN_TEST_ROLE;
GRANT CREATE INTEGRATION ON ACCOUNT TO ROLE QWEN_TEST_ROLE;
GRANT MONITOR USAGE ON ACCOUNT TO ROLE QWEN_TEST_ROLE;
GRANT BIND SERVICE ENDPOINT ON ACCOUNT TO ROLE QWEN_TEST_ROLE;
GRANT IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE TO ROLE QWEN_TEST_ROLE;
GRANT ROLE QWEN_TEST_ROLE TO ROLE ACCOUNTADMIN;

// Create Database, Warehouse, and Image stage
USE ROLE QWEN_TEST_ROLE;
CREATE OR REPLACE DATABASE TEST_QWEN_DB;
CREATE OR REPLACE SCHEMA TEST_QWEN_SCHEMA;

USE DATABASE TEST_QWEN_DB;
USE SCHEMA TEST_QWEN_SCHEMA;


////////////////////////////////////////////////////////////////////////////////////////////////////
// STEP 2
// Create the warehouse for the notebook and Compute Pools for the models
////////////////////////////////////////////////////////////////////////////////////////////////////

// Create the warehouse for notebook usage
// Note - this is not the compute that runs the models, just orchestrates the notebook itself.
CREATE OR REPLACE WAREHOUSE QWEN_NOTEBOOK_WH
    WAREHOUSE_SIZE = XSMALL
    AUTO_SUSPEND = 120
    AUTO_RESUME = TRUE;

// Create the compute pool for the demo. See documentation for CREATE COMPUTE POOL
// for more information on other INSTANCE_FAMILY values
CREATE COMPUTE POOL IF NOT EXISTS QWEN_POOL_S
    MIN_NODES = 1
    MAX_NODES = 1
    INSTANCE_FAMILY = GPU_NV_S
    AUTO_SUSPEND_SECS = 100
    AUTO_RESUME = true
    INITIALLY_SUSPENDED = true
    COMMENT = 'Small pool for running the qwen test notebook';
    
////////////////////////////////////////////////////////////////////////////////////////////////////
// STEP 3
// Create the external access integrations that allow us to access pypi and hugging face
////////////////////////////////////////////////////////////////////////////////////////////////////
USE ROLE ACCOUNTADMIN;

-- Integration 1: Huggingface to download image LLM models
CREATE OR REPLACE NETWORK RULE HUGGINGFACE_NETWORK_RULE
    TYPE = HOST_PORT
    MODE = EGRESS
    VALUE_LIST= ('huggingface.co', 'cdn-lfs.huggingface.co', 'cdn-lfs-us-1.huggingface.co',
                 'cdn-lfs.hf.co', 'cdn-lfs-us-1.hf.co');

CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION HUGGINGFACE_ACCESS_INTEGRATION
    ALLOWED_NETWORK_RULES = (HUGGINGFACE_NETWORK_RULE)
    ENABLED = true;

GRANT USAGE ON INTEGRATION HUGGINGFACE_ACCESS_INTEGRATION TO ROLE QWEN_TEST_ROLE;

-- Integration 2: Pypi for access to key python packages like `diffusers`
CREATE OR REPLACE NETWORK RULE PYPI_NETWORK_RULE
    TYPE = HOST_PORT
    MODE = EGRESS
    VALUE_LIST = ('pypi.org', 'pypi.python.org', 'pythonhosted.org',  'files.pythonhosted.org');

CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION PYPI_ACCESS_INTEGRATION
    ALLOWED_NETWORK_RULES = (PYPI_NETWORK_RULE)
    ENABLED = true;

GRANT USAGE ON INTEGRATION PYPI_ACCESS_INTEGRATION TO ROLE QWEN_TEST_ROLE;