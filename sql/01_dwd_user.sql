-- DWD 用户维表：一行一个用户，清洗改值不删行，按注册日期动态分区
CREATE TABLE IF NOT EXISTS dwd.dwd_user (
    user_id        INT,
    user_name      STRING,
    gender         STRING,
    age            INT,
    city           STRING,
    register_date  DATE
)
PARTITIONED BY (dt STRING)
ROW FORMAT DELIMITED FIELDS TERMINATED BY ',';

INSERT OVERWRITE TABLE dwd.dwd_user PARTITION (dt)
SELECT
    CAST(user_id AS INT)        AS user_id,
    TRIM(user_name)             AS user_name,
    CASE WHEN TRIM(gender) IN ('男', '女') THEN TRIM(gender) ELSE NULL END AS gender,
    CASE WHEN CAST(age AS INT) BETWEEN 1 AND 120 THEN CAST(age AS INT) ELSE NULL END AS age,
    COALESCE(NULLIF(TRIM(city), ''), '未知') AS city,
    CAST(register_date AS DATE) AS register_date,
    DATE_FORMAT(CAST(register_date AS DATE), 'yyyy-MM-dd') AS dt
FROM (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY register_date DESC) AS rn
    FROM ods.ods_users
) t
WHERE rn = 1;
