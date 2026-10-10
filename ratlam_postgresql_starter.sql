Create table ratlam(
Student_NAME text,
MOBILE_NUMBER text,
SCHOOL_NAME text,	
CITY text,
STREAM 	text,
CALLING_REMARK text
);

-- Data Check
select * from ratlam;

-- Total number of records
SELECT COUNT(*) AS total_records
FROM ratlam;

-- Check column-wise missing or blank values
SELECT
    COUNT(*) AS total_records,
    COUNT(*) FILTER (
        WHERE STUDENT_NAME IS NULL OR BTRIM(STUDENT_NAME) = ''
    ) AS missing_student_names,
    COUNT(*) FILTER (
        WHERE MOBILE_NUMBER IS NULL OR BTRIM(MOBILE_NUMBER) = ''
    ) AS missing_mobile_numbers,
    COUNT(*) FILTER (
        WHERE SCHOOL_NAME IS NULL OR BTRIM(SCHOOL_NAME) = ''
    ) AS missing_school_names,
    COUNT(*) FILTER (
        WHERE CITY IS NULL OR BTRIM(CITY) = ''
    ) AS missing_cities,
    COUNT(*) FILTER (
        WHERE STREAM IS NULL OR BTRIM(STREAM) = ''
    ) AS missing_streams,
    COUNT(*) FILTER (
        WHERE CALLING_REMARK IS NULL OR BTRIM(CALLING_REMARK) = ''
    ) AS missing_calling_remarks
FROM ratlam_final;


-- Cleaning New table 
DROP TABLE IF EXISTS ratlam_final;
-- Removes leading and trailing spaces.
-- Replaces text matching a regular expression.
-- Returns NULL when the value is an empty string.
-- Converts text to uppercase.
-- Converts text to lowercase for comparisons.
-- Capitalizes the first letter of each word.
-- Applies conditional cleaning or validation.
-- Checks whether a string matches a regular expression.
-- Substitutes a fallback value when the first value is NULL.
-- Removes duplicate rows based on all selected columns.
-- Defines temporary named query steps called CTEs.

CREATE TABLE ratlam_final AS
WITH normalized AS (
    SELECT
        NULLIF(
            REGEXP_REPLACE(
                BTRIM(STUDENT_NAME), '\s+', ' ', 'g'
            ), ''
        ) AS student_name,

        NULLIF(
            REGEXP_REPLACE(
                BTRIM(MOBILE_NUMBER), '[^0-9]', '', 'g'
            ), ''
        ) AS mobile_number_raw,

        NULLIF(
            REGEXP_REPLACE(
                BTRIM(SCHOOL_NAME), '\s+', ' ', 'g'
            ), ''
        ) AS school_name,

        NULLIF(
            REGEXP_REPLACE(
                BTRIM(CITY), '\s+', ' ', 'g'
            ), ''
        ) AS city,

        UPPER(
            NULLIF(
                REGEXP_REPLACE(
                    BTRIM(STREAM), '\s+', ' ', 'g'
                ), ''
            )
        ) AS stream,

        NULLIF(
            REGEXP_REPLACE(
                BTRIM(CALLING_REMARK), '\s+', ' ', 'g'
            ), ''
        ) AS calling_remark

    FROM ratlam
),
cleaned AS (
    SELECT
        CASE
            WHEN LOWER(student_name) IN
                 ('', 'unknown', 'n/a', 'na', 'null', 'none')
                THEN NULL
            ELSE INITCAP(student_name)
        END AS student_name,

        CASE
            WHEN mobile_number_raw ~ '^[6-9][0-9]{9}$'
                THEN mobile_number_raw
            ELSE NULL
        END AS mobile_number,

        CASE
            WHEN LOWER(school_name) IN
                 ('unknown', 'n/a', 'na', 'null', 'none')
                THEN NULL
            ELSE school_name
        END AS school_name,

        CASE
            WHEN LOWER(city) IN
                 ('unknown', 'n/a', 'na', 'null', 'none')
                THEN NULL
            ELSE INITCAP(city)
        END AS city,

        CASE
            WHEN LOWER(stream) IN
                 ('UNKNOWN', 'N/A', 'NA', 'NULL', 'NONE')
                THEN NULL
            ELSE stream
        END AS stream,

        CASE
            WHEN LOWER(calling_remark) IN
                 ('unknown', 'n/a', 'na', 'null', 'none')
                THEN NULL
            ELSE calling_remark
        END AS calling_remark

    FROM normalized
),
filtered AS (
    SELECT *
    FROM cleaned
    WHERE NOT (
        student_name IS NULL
        AND mobile_number IS NULL
        AND school_name IS NULL
        AND city IS NULL
        AND stream IS NULL
        AND calling_remark IS NULL
    )
    -- Remove obvious test/demo records.
    AND LOWER(COALESCE(student_name, '')) NOT IN
        ('test', 'demo', 'sample')
    AND LOWER(COALESCE(school_name, '')) NOT IN
        ('test', 'demo', 'sample', 'test school')
)
SELECT DISTINCT
    student_name,
    mobile_number,
    school_name,
    city,
    stream,
    calling_remark
FROM filtered;

-- Verify the final table.
SELECT COUNT(*) AS final_record_count
FROM ratlam_final;

SELECT *
FROM ratlam_final
LIMIT 50;



-- Final data-quality summary How many Data and Null Values Present
SELECT
    COUNT(*) AS total_records,
    COUNT(*) FILTER (
        WHERE student_name IS NULL
    ) AS missing_names,
    COUNT(*) FILTER (
        WHERE mobile_number IS NULL
    ) AS missing_valid_mobile,
    COUNT(*) FILTER (
        WHERE school_name IS NULL
    ) AS missing_schools,
    COUNT(*) FILTER (
        WHERE city IS NULL
    ) AS missing_cities,
    COUNT(*) FILTER (
        WHERE stream IS NULL
    ) AS missing_streams,
    COUNT(*) FILTER (
        WHERE calling_remark IS NULL
    ) AS missing_remarks
FROM ratlam_final;

-- Verify no exact duplicate rows remain
SELECT
    student_name,
    mobile_number,
    school_name,
    city,
    stream,
    calling_remark,
    COUNT(*) AS occurrences
FROM ratlam_final
GROUP BY
    student_name,
    mobile_number,
    school_name,
    city,
    stream,
    calling_remark
HAVING COUNT(*) > 1;

-- Calculates the total number of extra records associated with repeated phone numbers.

SELECT SUM(phone_count - 1) AS total_duplicate_phone_records
FROM (
    SELECT COUNT(*) AS phone_count
    FROM ratlam_final
    WHERE mobile_number IS NOT NULL
    GROUP BY mobile_number
    HAVING COUNT(*) > 1
) AS duplicates;

-- Identifies the repeated phone numbers and helps investigate why they are repeated.
SELECT
    mobile_number,
    COUNT(*) AS records,
    COUNT(DISTINCT student_name) AS student_names
FROM ratlam_final
WHERE mobile_number IS NOT NULL
GROUP BY mobile_number
HAVING COUNT(*) > 1
ORDER BY records DESC;

-- Display all records containing duplicate mobile numbers
SELECT
    mobile_number,
    ROW_NUMBER() OVER (
        PARTITION BY mobile_number
        ORDER BY student_name
    ) AS occurrence_no,
    COUNT(*) OVER (
        PARTITION BY mobile_number
    ) AS total_count,
    student_name,
    school_name,
    city,
    stream,
    calling_remark
FROM ratlam_final
WHERE mobile_number IS NOT NULL
  AND mobile_number IN (
      SELECT mobile_number
      FROM ratlam_final
      WHERE mobile_number IS NOT NULL
      GROUP BY mobile_number
      HAVING COUNT(*) > 1
  )
ORDER BY mobile_number, occurrence_no;

-- Delete Duplicate phn number and leave only original one 
WITH ranked AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY mobile_number
            ORDER BY
                (student_name IS NOT NULL)::int +
                (school_name IS NOT NULL)::int +
                (city IS NOT NULL)::int +
                (stream IS NOT NULL)::int +
                (calling_remark IS NOT NULL)::int DESC,
                student_name
        ) AS rn
    FROM ratlam_final
    WHERE mobile_number IS NOT NULL
)
SELECT *
FROM ranked
WHERE rn = 1
ORDER BY mobile_number;



BEGIN;

-- Check missing values using records sharing the same phone number.
WITH merged AS (
    SELECT
        mobile_number,
        MAX(student_name) AS student_name,
        MAX(school_name) AS school_name,
        MAX(city) AS city,
        MAX(stream) AS stream,
        MAX(calling_remark) AS calling_remark
    FROM ratlam_final
    WHERE mobile_number IS NOT NULL
    GROUP BY mobile_number
    HAVING COUNT(*) > 1
)
UPDATE ratlam_final AS t
SET
    student_name = COALESCE(t.student_name, m.student_name),
    school_name = COALESCE(t.school_name, m.school_name),
    city = COALESCE(t.city, m.city),
    stream = COALESCE(t.stream, m.stream),
    calling_remark = COALESCE(t.calling_remark, m.calling_remark)
FROM merged AS m
WHERE t.mobile_number = m.mobile_number;

-- Keep one record per phone number and delete the rest.
WITH ranked AS (
    SELECT
        ctid,
        ROW_NUMBER() OVER (
            PARTITION BY mobile_number
            ORDER BY
                (student_name IS NOT NULL)::int +
                (school_name IS NOT NULL)::int +
                (city IS NOT NULL)::int +
                (stream IS NOT NULL)::int +
                (calling_remark IS NOT NULL)::int DESC,
                student_name,
                ctid
        ) AS rn
    FROM ratlam_final
    WHERE mobile_number IS NOT NULL
)
DELETE FROM ratlam_final AS t
USING ranked AS r
WHERE t.ctid = r.ctid
  AND r.rn > 1;
  
-- Checking 

SELECT * FROM ratlam_final
WHERE mobile_number LIKE '%9685417535%';

-- Inspect results before making changes permanent.
SELECT mobile_number, COUNT(*) AS occurrences
FROM ratlam_final
WHERE mobile_number IS NOT NULL
GROUP BY mobile_number
HAVING COUNT(*) > 1;

select * from ratlam_final;

-- Invalind Phn Number 

SELECT MOBILE_NUMBER
FROM ratlam_final
WHERE MOBILE_NUMBER IS NULL
   OR BTRIM(MOBILE_NUMBER) !~ '^[0-9,\s+-]+$'
   OR EXISTS (
       SELECT 1
       FROM REGEXP_SPLIT_TO_TABLE(
           BTRIM(MOBILE_NUMBER), '\s*,\s*'
       ) AS n(phone)
       WHERE LENGTH(
           REGEXP_REPLACE(phone, '[^0-9]', '', 'g')
       ) < 9
          OR LENGTH(
           REGEXP_REPLACE(phone, '[^0-9]', '', 'g')
       ) > 10
   );

-- Delete Invalid Mobile Number
Delete from 
ratlam_final
WHERE MOBILE_NUMBER IS NULL
   OR BTRIM(MOBILE_NUMBER) !~ '^[0-9,\s+-]+$'
   OR EXISTS (
       SELECT 1
       FROM REGEXP_SPLIT_TO_TABLE(
           BTRIM(MOBILE_NUMBER), '\s*,\s*'
       ) AS n(phone)
       WHERE LENGTH(
           REGEXP_REPLACE(phone, '[^0-9]', '', 'g')
       ) < 9
          OR LENGTH(
           REGEXP_REPLACE(phone, '[^0-9]', '', 'g')
       ) > 10
   );

Select * from ratlam_final where calling_remark is null;

select * from ratlam_final;

select distinct calling_remark from ratlam;



-- Hindi Name's
SELECT *
FROM ratlam_final
WHERE student_name ~ '[\u0900-\u097F]'
   OR school_name ~ '[\u0900-\u097F]'
   OR city ~ '[\u0900-\u097F]'
   OR stream ~ '[\u0900-\u097F]'
   OR calling_remark ~ '[\u0900-\u097F]';

--  Converting Them To English 

Rollback;
BEGIN;

UPDATE ratlam_final
SET student_name = CASE student_name
    WHEN 'अनुराधा' THEN 'Anuradha'
    WHEN 'अर्जुन धनगर' THEN 'Arjun Dhangar'
    WHEN 'अश्विना आंजना' THEN 'Ashwina Anjana'
    WHEN 'कुमकुम धाकड़' THEN 'Kumkum Dhakad'
    WHEN 'गवरा गुर्जर' THEN 'Gawara Gurjar'
    WHEN 'गायत्री धाकड़' THEN 'Gayatri Dhakad'
    WHEN 'चंचल प्रजापत' THEN 'Chanchal Prajapat'
    WHEN 'जयदेव' THEN 'Jaydev'
    WHEN 'तिलक जोशी' THEN 'Tilak Joshi'
    WHEN 'ध्रुव चौहान' THEN 'Dhruv Chauhan'
    WHEN 'नारायण' THEN 'Narayan'
    WHEN 'नितेश हाडा' THEN 'Nitesh Hada'
    WHEN 'मंजू वाघेला' THEN 'Manju Vaghela'
    WHEN 'ममता मालवीय' THEN 'Mamta Malviya'
    WHEN 'मीनाक्षी शिकारी' THEN 'Meenakshi Shikari'
    WHEN 'वंदना व्यास' THEN 'Vandana Vyas'
    WHEN 'शुभम प्रजापत' THEN 'Shubham Prajapat'
    WHEN 'साक्षी परमार' THEN 'Sakshi Parmar'
    WHEN 'सुमित गायरी' THEN 'Sumit Gayari'
    ELSE student_name
END
WHERE student_name IN (
    'अनुराधा', 'अर्जुन धनगर', 'अश्विना आंजना',
    'कुमकुम धाकड़', 'गवरा गुर्जर', 'गायत्री धाकड़',
    'चंचल प्रजापत', 'जयदेव', 'तिलक जोशी',
    'ध्रुव चौहान', 'नारायण', 'नितेश हाडा',
    'मंजू वाघेला', 'ममता मालवीय', 'मीनाक्षी शिकारी',
    'वंदना व्यास', 'शुभम प्रजापत', 'साक्षी परमार',
    'सुमित गायरी'
);

-- Check the changes before saving
SELECT *
FROM ratlam_final
ORDER BY student_name;


--  Calling Remark

SELECT DISTINCT calling_remark
FROM ratlam_final
WHERE calling_remark IS NULL
  or calling_remark ~* 'wrong|wrog|worng|invalid|exist|not in use|service|switch|busy|network|incom|not (rec|ans|conn)'
ORDER BY 1;

-- Deleting Unnecessary Calling Remark

BEGIN;
Commit;
DELETE FROM ratlam_final
WHERE
      -- wrong number: WRONG NO., WORNG NUMBER, wrog number ...
      calling_remark ~* '(wrong|worng|wromg|wrog)\W+(\w+\W+){0,2}(no|nu\w*|nom\w*)(\W|$)'

      -- invalid number: INVALID NO., INVAILD NO. ...
   OR calling_remark ~* 'inva[il]*d'

      -- number does not exist: NO DOESN'T EXIST, THIS NUMBER DOESN`T EXIST, number does not exist ...
   OR calling_remark ~* '(doe?s|dose)\W*no?\W*t?\W*(ex|$)'

      -- number not in use: NO. NOT IN USE, THIS NUMBER IS NOT USE ...
   OR calling_remark ~* 'not\s+(in\s+)?use'

      -- out of / not in service: NOT IN SERVICE, OUT OF SERVICE, THIS NUMBER IS OUT OFF SERVICE ...
      -- (TEMP. OUT OF SERVICE is kept, because that number can work again later)
   OR (calling_remark ~* '(out\s+of+|not\s+in)\s+ser' AND calling_remark !~* 'temp');

-- check the number of rows left
SELECT COUNT(*) AS rows_remaining FROM ratlam_final;

-- More Cleaning 

BEGIN;
 
-- 1. Rename()
--    "Call incoming service not avelable" and
--    "call not connect /incoming call not available"
--    become "Incoming Unavailable" because they contain "incoming")
UPDATE ratlam_final AS f
SET calling_remark = m.new_remark
FROM (
    SELECT
        old_remark,
        CASE
            -- listed by you under "Busy"
            WHEN r = 'call cut, not answered the call'
                                                    THEN 'Busy'
 
            -- listed by you under "Incoming Unavailable"
            WHEN r IN ('this number out off network area',
                       'this number outoff network area')
                                                    THEN 'Incoming Unavailable'
 
            -- INCOMING ... (before Not Answered: "incoming call not received")
            WHEN r ~ '(^|\W)incom'                  THEN 'Incoming Unavailable'
 
            -- NOT ANSWERED: call not answered / received / connected, TEMP out of service
            --   (also "NOT CONNECTED/ALL LINES ARE BUSY", "NOT CONNECTED OR BUSY")
            WHEN r ~ 'not\s+(con+|cnn)e?c'
              OR r ~ 'temp.*ser'
              OR r ~ '(^|\W)not?e?\s+(rec|ans|asn)'
              OR r ~ 'call\s+not\s+att'             THEN 'Not Answered'
 
            -- BUSY: any remark that says busy
            WHEN r ~ 'busy'                         THEN 'Busy'
 
            -- SWITCH OFF: switched off, mobile off, out of network / range, network problem
            WHEN r ~ 'sw[a-z]{2,7}\s*off'
              OR r ~ '(^|\W)(mobile|mob|n[a-z]{2,5})\s+(is\s+)?off'
              OR r ~ 'out\s*of+\s*(network|range)|outside\s+network|not\s+in\s+cov|network\s+problem'
                                                    THEN 'Switch Off'
        END AS new_remark
    FROM (
        SELECT DISTINCT
               calling_remark              AS old_remark,
               lower(btrim(calling_remark)) AS r
        FROM ratlam_final
        WHERE calling_remark IS NOT NULL
    ) AS d
) AS m
WHERE f.calling_remark = m.old_remark
  AND m.new_remark IS NOT NULL;
 
-- 2. Check the result
SELECT calling_remark, COUNT(*) AS rows_count
FROM ratlam_final
WHERE calling_remark IN ('Busy', 'Not Answered', 'Incoming Unavailable', 'Switch Off') Or calling_remark is Null
GROUP BY calling_remark
ORDER BY rows_count DESC;

Select Count(*) from ratlam_final;
select * from ratlam_final;

-- Stream Data Cleaning Check  
Select distinct (Stream) from ratlam_final;


BEGIN;
 
-- Not a stream at all
UPDATE ratlam_final
SET stream = NULL
WHERE stream ~ '^\W*$'                          -- "-", empty text, only symbols
   OR upper(btrim(stream)) = 'REPEATED';
 
 
-- Standardise the names
-- The first matching rule wins, so the order matters.
UPDATE ratlam_final AS f
SET stream = m.new_stream
FROM (
    SELECT
        old_stream,
        CASE
            -- ---------- COMMERCE family ----------
            WHEN r ~ 'PCM' AND r ~ '(^|[^A-Z])COM'                 THEN 'PCM + Commerce'
            WHEN r ~ '(^|[^A-Z])COM' AND r ~ '(^|[^A-Z])ECO'       THEN 'Commerce + Economics'
            WHEN r ~ '(^|[^A-Z])COM' AND r ~ 'MATH'                THEN 'Commerce + Maths'
            WHEN r ~ '(^|[^A-Z])COM' AND r ~ '[^A-Z]I\.?\s*P\.?$'  THEN 'Commerce + IP'
            WHEN r ~ '(^|[^A-Z])COM'                               THEN 'Commerce'
            WHEN r ~ '(^|[^A-Z])ECO'                               THEN 'Economics'
 
            -- ---------- SCIENCE family ----------
            WHEN (r ~ 'PCM' AND r ~ 'BIO') OR r = 'PCMB'           THEN 'PCMB'
            WHEN r ~ 'BIO' AND r ~ 'MATH'                          THEN 'Bio + Maths'
            WHEN r = 'PCM'                                         THEN 'PCM'
            WHEN r = 'PCB'                                         THEN 'PCB'
            WHEN r ~ '^MATH'                                       THEN 'Maths'
            WHEN r ~ '^BIO'                                        THEN 'Biology'
            WHEN r ~ '^HOME'                                       THEN 'Home Science'
            WHEN r ~ '^SCI'                                        THEN 'Science'
 
            -- ---------- OTHER streams ----------
            WHEN r ~ '^AGRI'                                       THEN 'Agriculture'
            WHEN r ~ '^ART'                                        THEN 'Arts'
            WHEN r ~ '^HUMAN'                                      THEN 'Humanities'
        END AS new_stream
    FROM (
        SELECT DISTINCT
               stream AS old_stream,
               upper(regexp_replace(btrim(stream), '\s+', ' ', 'g')) AS r
        FROM ratlam_final
        WHERE stream IS NOT NULL
    ) AS d
) AS m
WHERE f.stream = m.old_stream
  AND m.new_stream IS NOT NULL
  AND f.stream IS DISTINCT FROM m.new_stream;
 
 
-- 3. Check the result: every stream value with its row count.
--    Anything that still looks wrong here was not recognised.
SELECT stream, COUNT(*) AS rows_count
FROM ratlam_final
GROUP BY stream
ORDER BY rows_count DESC;
 
-- City Data Cleaning Check
Select distinct city from ratlam_final order by city;

Select * from ratlam_final where student_name is null;
Select * from ratlam_final where student_name = 'Unknown';


-- Done !
-- As per client Demand
Select * from ratlam_final;
