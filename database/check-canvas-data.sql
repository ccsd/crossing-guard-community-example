-- all should be deleted for any instance
SELECT
 ed.course_id
, ed.created_at
, ed.updated_at
, ed.workflow_state
, pd.sis_user_id
, ed.type
FROM canvasdata.enrollment_dim ed
JOIN canvasdata.pseudonym_dim pd ON pd.user_id = ed.user_id AND pd.workflow_state = 'active'
WHERE pd.sis_user_id NOT LIKE 'F%'
AND ed.type NOT IN ('StudentEnrollment', 'ObserverEnrollment') 
ORDER BY created_at, updated_at