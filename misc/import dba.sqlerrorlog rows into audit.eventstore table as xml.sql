USE ETL
GO

DECLARE @dt datetimeoffset, 
		@xml xml;

DECLARE curs CURSOR LOCAL FORWARD_ONLY FOR
	SELECT 
		CreatedDate
	FROM DBA.LogSQLError
    ORDER BY CreatedDate;

OPEN curs;

FETCH NEXT FROM curs INTO @dt;

WHILE @@FETCH_STATUS = 0
BEGIN
	
	SET @xml = 
    (

    SELECT
        'error' AS evt_type,
        'alert' AS evt_status,
        SYSUTCDATETIME() AS err_dt,
        COALESCE(SQLErrorAnnounce,'') AS err_announce,
        COALESCE(SQLErrorSPID,'')  AS err_spid,
        COALESCE(SQLErrorProcedure,'') AS err_proc_nm,
        COALESCE(SQLErrorLineNumber,'') AS err_line,
        COALESCE(SQLErrorNumber,'') AS err_num,
        COALESCE(SQLErrorMessage,'') AS err_msg,
        COALESCE(SQLErrorSeverity,'') AS err_lvl,
        COALESCE(SQLErrorState,'') AS err_state,
        COALESCE('BMGMWIN36','') AS srv_nm,
        COALESCE('ETL','') AS db_nm,
		COALESCE(SQLErrorProcedureSection,'') AS sec_nm,
		COALESCE(SQLErrorEventInfo,'') AS evt_txt,
		COALESCE(SQLErrorExtraInfo,'') AS evt_info,
        COALESCE(CreatedByMachine,'') AS mach_nm,
        COALESCE(CreatedBy,'') AS usr_nm
    FROM DBA.LogSQLError
    WHERE CreatedDate = @dt
    FOR XML RAW ('event'), ELEMENTS
    );

    INSERT INTO Audit.EventSink (EventMessage) VALUES (@xml);
    
	FETCH NEXT FROM curs INTO @dt;
END

CLOSE curs;
DEALLOCATE curs;
