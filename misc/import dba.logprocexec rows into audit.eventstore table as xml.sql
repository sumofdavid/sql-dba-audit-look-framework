USE ETL
GO

DECLARE @log_id bigint, 
		@xml xml;

DECLARE curs CURSOR LOCAL FORWARD_ONLY FOR
	SELECT 
		LogProcExecGID
	FROM DBA.LogProcExec
    ORDER BY LogProcExecGID;

OPEN curs;

FETCH NEXT FROM curs INTO @log_id;

WHILE @@FETCH_STATUS = 0
BEGIN
	
	SET @xml = 
    (
    SELECT
        'proc exec' AS evt_type,
        'info' AS evt_status,
        LogProcExecGID AS log_id,
        COALESCE(ProcName,'') AS app_nm,
        COALESCE('BMGMWIN36','') AS srv_nm,
        COALESCE(DB_NAME(DatabaseID),'') AS db_nm,
        COALESCE(OBJECT_SCHEMA_NAME(ObjectID, DatabaseID),'') AS sch_nm,
		ProcExecStartTime AS bgn_dt,
		ProcExecEndTime AS end_dt,
		COALESCE(DatabaseID,0) AS [db_id],
		COALESCE(ProcExecVersion,NEWID()) AS [uid],
		COALESCE(ObjectID,0) AS obj_id,
		COALESCE(OBJECT_NAME(ObjectID, DatabaseID),COALESCE(ProcName,'unknown')) AS obj_nm,
		COALESCE(ProcSection,'') AS sec_nm,
		COALESCE(ProcText,'') AS evt_txt,
		COALESCE(ExtraInfo,'') AS evt_info,
		COALESCE(RowsAffected,'') AS [rows],
        COALESCE(CreatedByMachine,'') AS mach_nm,
        COALESCE(CreatedBy,'') AS usr_nm
    FROM DBA.LogProcExec
    WHERE LogProcExecGID = @log_id
    FOR XML RAW ('event'), ELEMENTS
    );

    INSERT INTO Audit.EventSink (EventMessage) VALUES (@xml);
    
	FETCH NEXT FROM curs INTO @log_id;
END

CLOSE curs;
DEALLOCATE curs;
