-- ============================================================
-- 02_storage_integration.sql
-- Purpose:
--   Create a Snowflake storage integration that allows Snowflake
--   to assume an AWS IAM role and read files from S3 securely.
--
-- Replace before running:
--   <AWS_ACCOUNT_ID> with your AWS account ID
--   <S3_BUCKET> with your S3 bucket name
--
-- Expected output from DESC INTEGRATION:
--   - STORAGE_AWS_IAM_USER_ARN
--   - STORAGE_AWS_EXTERNAL_ID
--   - STORAGE_AWS_ROLE_ARN
--
-- Important:
--   After running DESC INTEGRATION, update the AWS IAM role trust
--   policy with STORAGE_AWS_IAM_USER_ARN and STORAGE_AWS_EXTERNAL_ID.
-- ============================================================

CREATE OR REPLACE STORAGE INTEGRATION my_s3_int
  TYPE = EXTERNAL_STAGE
  STORAGE_PROVIDER = 'S3'
  ENABLED = TRUE
  STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::<AWS_ACCOUNT_ID>:role/SnowpipeS3Role'
  STORAGE_ALLOWED_LOCATIONS = ('s3://<S3_BUCKET>/incoming/');

DESC INTEGRATION my_s3_int;
