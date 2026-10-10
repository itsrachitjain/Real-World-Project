-- RAT LAM STUDENT DATA CLEANING PRACTICE: 50,000 SYNTHETIC ROWS
-- Import ratlam_raw_50000.csv into PostgreSQL table named ratlam.
-- All records are synthetic. Keep raw table unchanged; work in ratlam_final.

-- 1. Profile raw data
SELECT COUNT(*) AS total_records FROM ratlam;

SELECT
    COUNT(*) FILTER (WHERE STUDENT_NAME IS NULL OR BTRIM(STUDENT_NAME) = '') AS missing_student_names,
    COUNT(*) FILTER (WHERE MOBILE_NUMBER IS NULL OR BTRIM(MOBILE_NUMBER) = '') AS missing_mobile_numbers,
    COUNT(*) FILTER (WHERE SCHOOL_NAME IS NULL OR BTRIM(SCHOOL_NAME) = '') AS missing_school_names,
    COUNT(*) FILTER (WHERE CITY IS NULL OR BTRIM(CITY) = '') AS missing_cities,
    COUNT(*) FILTER (WHERE STREAM IS NULL OR BTRIM(STREAM) = '') AS missing_streams,
    COUNT(*) FILTER (WHERE CALLING_REMARK IS NULL OR BTRIM(CALLING_REMARK) = '') AS missing_calling_remarks
FROM ratlam;

-- 2. Explore all calling remarks before deciding what to standardize
SELECT BTRIM(CALLING_REMARK) AS calling_remark, COUNT(*) AS records
FROM ratlam
GROUP BY BTRIM(CALLING_REMARK)
ORDER BY records DESC;

-- 3. Create cleaned working table; keep original ratlam unchanged
DROP TABLE IF EXISTS ratlam_final;
CREATE TABLE ratlam_final AS
SELECT
    NULLIF(BTRIM(REGEXP_REPLACE(COALESCE(STUDENT_NAME,''), '\\s+', ' ', 'g')), '') AS STUDENT_NAME,
    NULLIF(REGEXP_REPLACE(COALESCE(MOBILE_NUMBER,''), '\\D', '', 'g'), '') AS MOBILE_NUMBER,
    NULLIF(BTRIM(REGEXP_REPLACE(COALESCE(SCHOOL_NAME,''), '\\s+', ' ', 'g')), '') AS SCHOOL_NAME,
    NULLIF(BTRIM(REGEXP_REPLACE(COALESCE(CITY,''), '\\s+', ' ', 'g')), '') AS CITY,
    UPPER(NULLIF(BTRIM(REGEXP_REPLACE(COALESCE(STREAM,''), '\\s+', ' ', 'g')), '')) AS STREAM,
    NULLIF(BTRIM(REGEXP_REPLACE(COALESCE(CALLING_REMARK,''), '\\s+', ' ', 'g')), '') AS CALLING_REMARK
FROM ratlam;

-- 4. Inspect mobile numbers and repeated phones before any removal/merging
SELECT * FROM ratlam_final
WHERE MOBILE_NUMBER IS NULL OR MOBILE_NUMBER !~ '^[6-9][0-9]{9}$';

SELECT MOBILE_NUMBER, COUNT(*) AS records
FROM ratlam_final
WHERE MOBILE_NUMBER IS NOT NULL
GROUP BY MOBILE_NUMBER
HAVING COUNT(*) > 1
ORDER BY records DESC;

-- 5. Inspect calling remark scenarios (JEE/NEET, preparation, admission, counselling, follow-up, call outcomes)
SELECT UPPER(BTRIM(CALLING_REMARK)) AS remark, COUNT(*) AS records
FROM ratlam_final
GROUP BY UPPER(BTRIM(CALLING_REMARK))
ORDER BY records DESC;

-- 6. Remove records only when the remark clearly indicates an unusable number.
-- This pattern intentionally does NOT remove "TEMPORARILY OUT OF SERVICE".
-- Review the matched rows first before running DELETE.
SELECT *
FROM ratlam_final
WHERE CALLING_REMARK ~* '(wrong number|invalid number|number does not exist|number not in use|out of service)';

-- After review, if appropriate:
-- DELETE FROM ratlam_final
-- WHERE CALLING_REMARK ~* '(wrong number|invalid number|number does not exist|number not in use|out of service)';

-- 7. Standardize known call outcomes, but preserve education/admission scenarios as separate remarks.
UPDATE ratlam_final
SET CALLING_REMARK = CASE
    WHEN LOWER(BTRIM(CALLING_REMARK)) IN ('busy','line busy','call busy','number busy','b u s y') THEN 'Busy'
    WHEN LOWER(BTRIM(CALLING_REMARK)) IN ('not answered','no answer','not picked','ringing no response','call not answered','not responding','no response') THEN 'Not Answered'
    WHEN LOWER(BTRIM(CALLING_REMARK)) IN ('incoming unavailable','incoming not available','incoming facility unavailable','incoming is not available','incoming barred') THEN 'Incoming Unavailable'
    WHEN LOWER(BTRIM(CALLING_REMARK)) IN ('switch off','switched off','phone off','mobile switched off','off') THEN 'Switch Off'
    ELSE INITCAP(BTRIM(CALLING_REMARK))
END
WHERE CALLING_REMARK IS NOT NULL;

-- 8. Review education/admission remark categories (examples)
SELECT
    CASE
        WHEN CALLING_REMARK ~* '\\m(JEE|NEET|CUET|NDA)\\M' THEN 'Entrance Exam'
        WHEN CALLING_REMARK ~* '(not prepar|preparation not started|still deciding)' THEN 'Preparation Status'
        WHEN CALLING_REMARK ~* '(admission|enrolled|another college)' THEN 'Admission Status'
        WHEN CALLING_REMARK ~* '(call back|call after|asked to call|will confirm later)' THEN 'Follow-up Required'
        WHEN CALLING_REMARK ~* '(fee|scholarship|hostel|transport|brochure|details sent)' THEN 'Information Requested'
        WHEN CALLING_REMARK ~* '(counselling|visit planned|visited campus)' THEN 'Counselling/Campus Visit'
        WHEN CALLING_REMARK ~* '(busy|not answered|switch off|incoming unavailable|no response)' THEN 'Call Outcome'
        ELSE 'Other / Review'
    END AS remark_category,
    COUNT(*) AS records
FROM ratlam_final
GROUP BY remark_category
ORDER BY records DESC;

-- 9. Exact duplicate check and final checks
SELECT STUDENT_NAME, MOBILE_NUMBER, SCHOOL_NAME, CITY, STREAM, CALLING_REMARK, COUNT(*) AS copies
FROM ratlam_final
GROUP BY STUDENT_NAME, MOBILE_NUMBER, SCHOOL_NAME, CITY, STREAM, CALLING_REMARK
HAVING COUNT(*) > 1;

SELECT COUNT(*) AS final_records FROM ratlam_final;
SELECT MOBILE_NUMBER, COUNT(*) AS records
FROM ratlam_final
GROUP BY MOBILE_NUMBER
HAVING COUNT(*) > 1;
